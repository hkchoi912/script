#include <iostream>
#include <fstream>
#include <string>
#include <regex>
#include <cinttypes>
#include <queue>

#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <libaio.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <linux/fs.h>
#include <stddef.h>

#define SEC_TO_NS 1000000000
#define MAX_DEPTH 1024
#define MAX_EVENT 32
#define RANDOM_FILE "random.bin"

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
      }
      else {
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
      }
      else {
        ret = (head == 0);
        head = 1;
      }

      return ret;
    }

    int getTail() { return tail; }
    int getHead() { return head; }
};

void delay_ns(struct timespec *req) {
  struct timespec remain;

  do {
    int ret = clock_nanosleep(CLOCK_MONOTONIC, 0, req, &remain);

    if (ret == EINTR) {
      req->tv_sec = remain.tv_sec;
      req->tv_nsec = remain.tv_nsec;
    }
    else {
      break;
    }
  } while (true);
}

void sleep_ns(struct timespec *req) {
  struct timespec remain;

  do {
    int ret = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, req, &remain);

    if (ret == EINTR) {
      req->tv_sec = remain.tv_sec;
      req->tv_nsec = remain.tv_nsec;
    }
    else {
      break;
    }
  } while (true);
}

size_t blkdev_size(int fd) {
  size_t ret = 0;

  if (ioctl(fd, BLKGETSIZE64, &ret) < 0) {
    perror("ioctl");

    return 0;
  }

  return ret;
}

// Time in seconds, Action, Action, Offset, Length
std::regex regex_blkparse("\\d+,\\d+ +\\d+ +\\d+ +(\\d+)\\.(\\d+) +\\d+ +(\\w) +(\\w+) +(\\d+) \\+ (\\d+).*");

int main(int argc, char *argv[]) {
  struct timespec start, end, timeout;
  struct timespec iobegin, ioend;
  char *devname = nullptr;
  char *tracepath = nullptr;
  long delay = 0;
  uint64_t limit = 0;
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
  if (argc >= 3) {
    devname = argv[1];
    tracepath = argv[2];
  }
  if (argc >= 4) {
    delay = atol(argv[3]);
  }
  if (argc == 5) {
    limit = strtoull(argv[4], nullptr, 10) * 1000000;
  }
  if (argc < 3 || argc > 5) {
    std::cerr << "Invalid number of arguments." << std::endl;
    std::cerr << argv[0] << " <device> <trace file> <delay (s)> <limit (ms)>" << std::endl;

    return 1;
  }

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

  // Open trace file
  trace.open(tracepath);

  if (!trace.is_open()) {
    std::cerr << "Failed to open trace file." << std::endl;

    goto QUEUE_RELEASE;
  }

  // Initialize job
  {
    jobs = (struct iocb *)calloc(MAX_DEPTH, sizeof(struct iocb));

    for (uint32_t i = 0; i < MAX_DEPTH; i++) {
      emptyslot.push(i);
    }
  }

  // Delay calculation
  clock_gettime(CLOCK_MONOTONIC, &end);

  if (end.tv_nsec >= start.tv_nsec) {
    end.tv_sec -= start.tv_sec;
    end.tv_nsec -= start.tv_nsec;
  }
  else {
    end.tv_sec = end.tv_sec - start.tv_sec - 1;
    end.tv_nsec = SEC_TO_NS - start.tv_nsec + end.tv_nsec;
  }

  if (end.tv_sec < delay) {
    if (end.tv_nsec == 0) { // 0 >= end.tv_nsec
      end.tv_sec = delay - end.tv_sec;
    }
    else {
      end.tv_sec = delay - end.tv_sec - 1;
      end.tv_nsec = SEC_TO_NS - end.tv_nsec;
    }

    std::cout << "Sleep " << end.tv_sec << "." << end.tv_nsec << "s" << std::endl;

    // Sleep
    delay_ns(&end);
  }

  // Loop the trace file
  start.tv_sec = 0;
  start.tv_nsec = 0;
  timeout.tv_sec = 0;
  timeout.tv_nsec = 1;

  std::cout << "Begin I/O replay." << std::endl;

  clock_gettime(CLOCK_MONOTONIC, &iobegin);

  while (!trace.eof()) {
    int ret;
    std::string line;
    std::smatch match;

    std::getline(trace, line);

    if (std::regex_match(line, match, regex_blkparse)) {
      // Check dispatch
      if (match[3].str().at(0) == 'Q') {
        char rwsb = match[4].str().at(0);

        // Check rwsb
        if (rwsb != 'R' && rwsb != 'W') {
          continue;
        }

        // Get time value
        start.tv_sec = atoll(match[1].str().c_str()) / TIME_FACTOR + iobegin.tv_sec;
        start.tv_nsec = atol(match[2].str().c_str()) / TIME_FACTOR + iobegin.tv_nsec;

        if (start.tv_nsec >= SEC_TO_NS) {
          start.tv_sec += 1;
          start.tv_nsec -= SEC_TO_NS;
        }

        // Sleep
        sleep_ns(&start);

        // Dispatch
        if (queue.incTail()) {
          struct iocb *iocb;
          uint64_t offset, length;
          uint32_t index;

          // Get job
          if (emptyslot.size() == 0) {
            std::cerr << "Failed to allocate job." << std::endl;

            break;
          }

          index = emptyslot.top();
          emptyslot.pop();

          iocb = jobs + index;

          offset = (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10) * 512;
          length = (uint64_t)strtoull(match[6].str().c_str(), nullptr, 10) * 512;

          // Limit check
          if (offset >= devsize) {
            offset %= devsize;
          }
          if (offset + length > devsize) {
            offset -= length;
          }

          // Create request
          if (rwsb == 'R') {
            read++;
            readsize += length;

            io_prep_pread(iocb, devfile, buffer + buffersize * index, length, offset);
          }
          else {
            writesize += length;

            io_prep_pwrite(iocb, devfile, buffer + buffersize * index, length, offset);
          }

          // Submit request
          do {
            ret = io_submit(ctx, 1, &iocb);
          } while (ret == -EAGAIN);

          if (ret < 0) {
            std::cerr << "Failed to submit request." << std::endl;

            break;
          }

          submitted++;
        }
      }
    }

    ret = io_getevents(ctx, 0, MAX_EVENT, event, &timeout);
    if (ret < 0) {
      std::cerr << "Failed to get events." << std::endl;

      break;
    }

    if (ret > 0) {
      for (uint32_t i = 0; i < ret; i++) {
        struct iocb *iocb = event[i].obj;

        queue.incHead();
        emptyslot.push((iocb - jobs) / sizeof(struct iocb));

        completed++;
      }
    }
  }

  // Still we need to check
  while (submitted != completed) {
    int ret;

    ret = io_getevents(ctx, 0, MAX_EVENT, event, &timeout);
    if (ret < 0) {
      std::cerr << "Failed to get events." << std::endl;

      break;
    }

    if (ret > 0) {
      for (uint32_t i = 0; i < ret; i++) {
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
  }
  else {
    ioend.tv_sec = ioend.tv_sec - iobegin.tv_sec - 1;
    ioend.tv_nsec = SEC_TO_NS - iobegin.tv_nsec + ioend.tv_nsec;
  }

  std::cout << "Done." << std::endl;
  std::cout << " I/O time: " << ioend.tv_sec << "." << ioend.tv_nsec << std::endl;
  std::cout << " Total I/O count: " << submitted << " ( " << read << " / " << submitted - read << " )" << std::endl;
  std::cout << " Total I/O size: " << readsize + writesize << " ( " << readsize << " / " << writesize << " )" << std::endl;

  free(jobs);
QUEUE_RELEASE:
  io_queue_release(ctx);
CLOSE_DEVICE:
  close(devfile);
BUFFER_FREE:
  free(buffer);

  return 0;
}
