#include <iostream>
#include <fstream>
#include <string>
#include <regex>
#include <errno.h>
#include <time.h>
#include <linux/fs.h>

#define MAX_IDX 100000

struct regexio
{
    __time_t tv_sec;
    __syscall_slong_t tv_nsec;
    const char *action;
    const char *iotype;
    uint64_t offset;
    uint64_t length;
};

// Time in seconds, Action, Action, Offset, Length
std::regex regex_blkparse("\\d+,\\d+ +\\d+ +\\d+ +(\\d+)\\.(\\d+) +\\d+ +(\\w) +(\\w+) +(\\d+) \\+ (\\d+).*");

int main(int argc, char *argv[])
{
    char *tracepath = nullptr;
    char *readpath = nullptr;
    char *writepath = nullptr;

    std::ifstream trace;
    std::ofstream readoutput;
    std::ofstream writeoutput;

    int i = 0, j = 0, k = 0, l = 0;

    struct regexio readDlog[MAX_IDX];
    struct regexio WriteDlog[MAX_IDX];

    // Read device name, trace file and delay
    if (argc >= 4)
    {
        tracepath = argv[1];
        readpath = argv[2];
        writepath = argv[3];
    }
    if (argc < 4)
    {
        std::cerr << "Invalid number of arguments." << std::endl;
        std::cerr << argv[0] << " <trace file> <read output file> <write output file>" << std::endl;
        return 1;
    }

    // Open trace file
    trace.open(tracepath);
    readoutput.open(readpath, std::ofstream::out | std::ofstream::trunc);   // open with delete contents
    writeoutput.open(writepath, std::ofstream::out | std::ofstream::trunc); // open with delete contents

    if (!trace.is_open())
    {
        std::cerr << "Failed to open trace file." << std::endl;
        return 1;
    }

    std::cout << "Begin parsing." << std::endl;

    while (!trace.eof())
    {
        int ret;
        std::string line;
        std::smatch match;

        std::getline(trace, line);

        /* 
         * match[0] : line
         * match[1] : sec
         * match[2] : msec
         * match[3] : Action
         * match[4] : io type
         */
        if (std::regex_match(line, match, regex_blkparse))
        {
            if (match[3].str().at() == 'D')
            {
                char rwsb = match[4].str().c_str();

                if (rwsb != 'R' && rwsb != 'W')
                {
                    continue;
                }

                if (rwsb == 'R')
                {
                    readDlog[i].tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                    readDlog[i].tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                    readDlog[i].action = match[3].str().c_str();
                    readDlog[i].iotype = match[4].str().c_str();
                    readDlog[i].offset = (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10);
                    readDlog[i].length = (uint64_t)strtoull(match[6].str().c_str(), nullptr, 10);
                    i++;
                }
                else
                {
                    writeDlog[j].tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                    writeDlog[j].tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                    writeDlog[j].action = match[3].str().c_str();
                    writeDlog[j].iotype = match[4].str().c_str();
                    writeDlog[j].offset = (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10);
                    writeDlog[j].length = (uint64_t)strtoull(match[6].str().c_str(), nullptr, 10);
                    j++;
                }
            }
            else if (match[3].str().at() == 'C')
            {
                char rwsb = match[4].str().c_str();

                if (rwsb != 'R' && rwsb != 'W')
                {
                    continue;
                }

                if (rwsb == 'R')
                {
                    for (k = i - 1; k >= 0; k--)
                    {
                        if (readDlog[k].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10))
                        {
                            //todo. continue 확인 필요
                            readoutput.write(readDlog[k].offset, sizeof(uint64_t));
                            continue;
                        }
                    }
                }
                else
                {
                    for (l = j - 1; j >= 0; j--) {
                        if (writeDlog[k].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10)) {
                            writeoutput.write(writeDlog[k].offset,, sizeof(uint64_t));
                            continue;
                        }
                    }
                }
            }

            // if (match[3].str().at(0) == 'D')
            // {
            //     char rwsb = match[4].str().at(0);
            //     // Check rwsb
            //     if (rwsb != 'R' && rwsb != 'W')
            //     {
            //         continue;
            //     }
            //     output.write(match[0].str().c_str(), line.length());
            //     output.write("\n", 1);
            // }
        }
    }

    return 0;
}
