#include <errno.h>
#include <fcntl.h>
#include <libaio.h>
#include <linux/fs.h>
#include <stddef.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <cinttypes>
#include <fstream>
#include <iostream>
#include <queue>
#include <regex>
#include <string>

#define SEC_TO_NS 1000000000
#define MAX_DEPTH 2048  // ~1024
#define MAX_EVENT 32
#define RANDOM_FILE "/home/hkchoi/script/iod/replayer/random.bin"

#define BLOCKSIZE 16384
#define SECTORSIZE 512
#define MAKE_ALIGNED_OFFSET(x, a) (((x) / (a)) * (a))

#ifndef TIME_FACTOR
#define TIME_FACTOR 1
#endif

class Queue {
   private:
    int head;
    int tail;
    int size;

   public:
    Queue(int depth) : head(0), tail(0), size(depth) {}

    int incHead() {
        if (size > 1) {
            head++;

            if (head == size) {
                head = 0;
            }
        } else {
            head = 0;
        }

        return head;
    }

    bool incTail() {
        bool ret = true;

        if (size > 1) {
            int old_tail = tail;

            tail++;

            if (tail == size) {
                tail = 0;
            }

            if (tail == head) {
                tail = old_tail;
                ret = false;
            }
        } else {
            ret = (head == 0);
            head = 1;
        }

        return ret;
    }

    int getTail() { return tail; }
    int getHead() { return head; }
};

size_t blkdev_size(int fd) {
    size_t ret = 0;

    if (ioctl(fd, BLKGETSIZE64, &ret) < 0) {
        perror("ioctl");

        return 0;
    }

    return ret;
}

int main(int argc, char *argv[]) {
    struct timespec start, timeout;
    struct timespec iobegin, ioend;
    char *devname = nullptr;
    uint32_t buffersize = 0;
    uint8_t *buffer = nullptr;
    size_t devsize = 0;

    io_context_t ctx;
    struct io_event event[MAX_EVENT];
    std::ifstream trace;
    int devfile = 0;
    Queue queue(MAX_DEPTH);
    struct iocb *jobs = nullptr;
    std::priority_queue<uint32_t> emptyslot;

    uint32_t submitted = 0;
    uint32_t completed = 0;

    uint32_t read = 0;
    uint64_t readsize = 0;
    uint64_t writesize = 0;

    // Begin of program
    clock_gettime(CLOCK_MONOTONIC, &start);

    // Read device name, trace file and delay

    if (argc != 4) {
        std::cerr << "Invalid number of arguments." << std::endl;
        std::cerr << argv[0] << " <device> <address 1> <address 2>" << std::endl;

        return 1;
    }

    devname = argv[1];

    uint64_t offset_1 = strtoull(argv[2], nullptr, 10);
    uint64_t offset_2 = strtoull(argv[3], nullptr, 10);

    // Read buffer
    {
        std::ifstream randfile(RANDOM_FILE);

        if (!randfile.is_open()) {
            std::cerr << "Failed to open random buffer file." << std::endl;

            return 2;
        }

        randfile.seekg(0, std::ios::end);
        buffersize = randfile.tellg();
        randfile.seekg(0, std::ios::beg);

        if (posix_memalign((void **)&buffer, buffersize, buffersize * MAX_DEPTH) != 0) {
            std::cerr << "Failed to allocate buffer." << std::endl;

            return 3;
        }

        for (uint32_t i = 0; i < MAX_DEPTH; i++) {
            randfile.read((char *)buffer + i * buffersize, buffersize);
            randfile.seekg(0, std::ios::beg);
        }

        randfile.close();
    }

    // Open device
    devfile = open(devname, O_RDWR | O_DIRECT);

    if (devfile > 0) {
        struct stat sb;

        if (fstat(devfile, &sb) == 0) {
            switch (sb.st_mode & S_IFMT) {
                case S_IFBLK:
                    devsize = blkdev_size(devfile);
                    break;
                case S_IFREG:
                    devsize = sb.st_size;
                    break;
            }
        }
    }

    if (devsize == 0) {
        std::cerr << "Failed to open device." << std::endl;

        goto BUFFER_FREE;
    }

    // Init I/O context
    if (io_queue_init(MAX_DEPTH, &ctx) != 0) {
        std::cerr << "Failed to initialize libaio." << std::endl;

        goto CLOSE_DEVICE;
    }

    // Initialize job
    {
        jobs = (struct iocb *)calloc(MAX_DEPTH, sizeof(struct iocb));

        for (uint32_t i = 0; i < MAX_DEPTH; i++) {
            emptyslot.push(i);
        }
    }

    // Loop the trace file
    start.tv_sec = 0;
    start.tv_nsec = 0;
    timeout.tv_sec = 0;
    timeout.tv_nsec = 1;

    std::cout << "Begin I/O replay." << std::endl;

    clock_gettime(CLOCK_MONOTONIC, &iobegin);

    {
        queue.incTail();
        queue.incTail();

        struct iocb *iocb[2];
        uint32_t index[2];
        int ret = 0;

        // Get job
        if (emptyslot.size() <= 1) {
            std::cerr << "Failed to allocate job." << std::endl;

            goto end;
        }

        index[0] = emptyslot.top();
        emptyslot.pop();
        index[1] = emptyslot.top();
        emptyslot.pop();

        iocb[0] = jobs + index[0];
        iocb[1] = jobs + index[1];

        offset_1 = MAKE_ALIGNED_OFFSET(offset_1 * SECTORSIZE, BLOCKSIZE);
        offset_2 = MAKE_ALIGNED_OFFSET(offset_2 * SECTORSIZE, BLOCKSIZE);

        // Limit check
        if (offset_1 >= devsize) {
            offset_1 %= devsize;
        }
        if (offset_1 + BLOCKSIZE > devsize) {
            offset_1 -= BLOCKSIZE;
        }
        if (offset_2 >= devsize) {
            offset_2 %= devsize;
        }
        if (offset_2 + BLOCKSIZE > devsize) {
            offset_2 -= BLOCKSIZE;
        }

        // Create request
        io_prep_pread(iocb[0], devfile, buffer + buffersize * index[0], BLOCKSIZE, offset_1);
        io_prep_pread(iocb[1], devfile, buffer + buffersize * index[1], BLOCKSIZE, offset_2);

        // Submit request
        do {
            ret = io_submit(ctx, 2, iocb);
        } while (ret == -EAGAIN);

        if (ret < 0) {
            std::cerr << "Failed to submit request." << std::endl;

            goto end;
        }

        submitted += 2;

        ret = io_getevents(ctx, 0, MAX_EVENT, event, &timeout);
        if (ret < 0) {
            std::cerr << "Failed to get events." << std::endl;

            goto end;
        }

        if (ret > 0) {
            for (int i = 0; i < ret; i++) {
                struct iocb *iocb = event[i].obj;

                queue.incHead();
                emptyslot.push((iocb - jobs) / sizeof(struct iocb));

                completed++;
            }
        }
    }

end:
    // Still we need to check
    while (submitted != completed) {
        int ret;

        ret = io_getevents(ctx, 0, MAX_EVENT, event, &timeout);
        if (ret < 0) {
            std::cerr << "Failed to get events." << std::endl;

            break;
        }

        if (ret > 0) {
            for (int i = 0; i < ret; i++) {
                struct iocb *iocb = event[i].obj;

                queue.incHead();
                emptyslot.push((iocb - jobs) / sizeof(struct iocb));

                completed++;
            }
        }
    }

    // Cleanup
    clock_gettime(CLOCK_MONOTONIC, &ioend);

    if (ioend.tv_nsec >= iobegin.tv_nsec) {
        ioend.tv_sec -= iobegin.tv_sec;
        ioend.tv_nsec -= iobegin.tv_nsec;
    } else {
        ioend.tv_sec = ioend.tv_sec - iobegin.tv_sec - 1;
        ioend.tv_nsec = SEC_TO_NS - iobegin.tv_nsec + ioend.tv_nsec;
    }

    std::cout << "Done." << std::endl;
    std::cout << " I/O time: " << ioend.tv_sec << "." << ioend.tv_nsec << std::endl;
    std::cout << " Total I/O count: " << submitted << " ( " << read << " / " << submitted - read << " )" << std::endl;
    std::cout << " Total I/O size: " << readsize + writesize << " ( " << readsize << " / " << writesize << " )" << std::endl;

    free(jobs);
    io_queue_release(ctx);
CLOSE_DEVICE:
    close(devfile);
BUFFER_FREE:
    free(buffer);

    return 0;
}
