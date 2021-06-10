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
#include <string>

#define MAX_DEPTH 10000

std::string double_to_string(double t)
{
    std::stringstream sstr;
    sstr << t;
    return sstr.str();
}

struct regexio
{
    __time_t tv_sec;
    __syscall_slong_t tv_nsec;
    const char *action;
    const char *iotype;
    uint64_t offset;
    uint64_t length;
    const char *workload;
};

// Time in seconds, Action, Action, Offset, Length
// std::regex regex_blkparse("\\d+,\\d+ +\\d+ +\\d+ +(\\d+)\\.(\\d+) +\\d+ +(\\w) +(\\w+) +(\\d+) \\+ (\\d+).*");
std::regex regex_blkparse("\\d+,\\d+ +\\d+ +\\d+ +(\\d+)\\.(\\d+) +\\d+ +(\\w) +(\\w+) +(\\d+) \\+ (\\d+) +\\[(.*)\\].*");

int main(int argc, char *argv[])
{
    char *tracepath = nullptr;
    char *readpath = nullptr;
    char *writepath = nullptr;

    std::ifstream trace;
    std::ofstream readoutput;
    std::ofstream writeoutput;

    int i = 0, j = 0, k = 0, l = 0;
    bool readfind, writefind;

    struct regexio readDlog[MAX_DEPTH];
    struct regexio writeDlog[MAX_DEPTH];

    struct timespec D2Ctime, Ctime, Dtime;

    std::string strout;

    // Read device name, trace file and delay
    if (argc == 4)
    {
        tracepath = argv[1];
        readpath = argv[2];
        writepath = argv[3];
    }
    if (argc != 4)
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
         * match[5] : offset
         * match[6] : length
         * match[7] : workload
         */
        if (std::regex_match(line, match, regex_blkparse))
        {
            if (match[3].str().at(0) == 'D')
            {
                char rwsb = match[4].str().at(0);

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
                    readDlog[i].workload = match[7].str().c_str();

                    if (i < MAX_DEPTH - 1)
                        i++;
                    else
                        i = 0;
                }
                else
                {
                    writeDlog[j].tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                    writeDlog[j].tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                    writeDlog[j].action = match[3].str().c_str();
                    writeDlog[j].iotype = match[4].str().c_str();
                    writeDlog[j].offset = (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10);
                    writeDlog[j].length = (uint64_t)strtoull(match[6].str().c_str(), nullptr, 10);
                    writeDlog[j].workload = match[7].str().c_str();

                    if (j < MAX_DEPTH)
                        j++;
                    else
                        j = 0;
                }
            }
            else if (match[3].str().at(0) == 'C')
            {
                char rwsb = match[4].str().at(0);
                readfind = false;
                writefind = false;

                if (rwsb != 'R' && rwsb != 'W')
                {
                    continue;
                }

                if (rwsb == 'R')
                {
                    if (i != 0)
                    {
                        for (k = i - 1; k >= 0; k--)
                        {
                            if (readDlog[k].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10))
                            {
                                Ctime.tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                                Ctime.tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                                Dtime.tv_sec = readDlog[k].tv_sec;
                                Dtime.tv_nsec = readDlog[k].tv_nsec;

                                if (Ctime.tv_nsec - Dtime.tv_nsec >= 0)
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec;
                                    D2Ctime.tv_nsec = Ctime.tv_nsec - Dtime.tv_nsec;
                                }
                                else
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec - 1;
                                    D2Ctime.tv_nsec = 1000000000 + Ctime.tv_nsec - Dtime.tv_nsec;
                                }

                                strout = "";
                                strout += double_to_string(Dtime.tv_sec + (double)Dtime.tv_nsec / (double)1000000000) + " ";
                                // strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + " " +readDlog[k].workload + "\n";
                                strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + "\n";
                                readoutput.write(strout.c_str(), strout.length());

                                readfind = true;
                                break;
                            }
                        }
                    }
                    if (!readfind)
                    {
                        for (k = MAX_DEPTH - 1; k >= i; k--)
                        {
                            if (readDlog[k].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10))
                            {
                                Ctime.tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                                Ctime.tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                                Dtime.tv_sec = readDlog[k].tv_sec;
                                Dtime.tv_nsec = readDlog[k].tv_nsec;

                                if (Ctime.tv_nsec - Dtime.tv_nsec >= 0)
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec;
                                    D2Ctime.tv_nsec = Ctime.tv_nsec - Dtime.tv_nsec;
                                }
                                else
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec - 1;
                                    D2Ctime.tv_nsec = 1000000000 + Ctime.tv_nsec - Dtime.tv_nsec;
                                }

                                strout = "";
                                strout += double_to_string(Dtime.tv_sec + (double)Dtime.tv_nsec / (double)1000000000) + " ";
                                // strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + " " +readDlog[k].workload + "\n";
                                strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + "\n";
                                readoutput.write(strout.c_str(), strout.length());

                                readfind = true;
                                break;
                            }
                        }
                    }
                }
                else
                {
                    if (j != 0)
                    {
                        for (l = j - 1; l >= 0; l--)
                        {
                            if (writeDlog[l].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10))
                            {
                                Ctime.tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                                Ctime.tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                                Dtime.tv_sec = writeDlog[l].tv_sec;
                                Dtime.tv_nsec = writeDlog[l].tv_nsec;

                                if (Ctime.tv_nsec - Dtime.tv_nsec >= 0)
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec;
                                    D2Ctime.tv_nsec = Ctime.tv_nsec - Dtime.tv_nsec;
                                }
                                else
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec - 1;
                                    D2Ctime.tv_nsec = 1000000000 + Ctime.tv_nsec - Dtime.tv_nsec;
                                }

                                strout = "";
                                strout += double_to_string(Dtime.tv_sec + (double)Dtime.tv_nsec / (double)1000000000) + " ";
                                // strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + " " +writeDlog[l].workload + "\n";
                                strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + "\n";
                                writeoutput.write(strout.c_str(), strout.length());

                                writefind = true;
                                break;
                            }
                        }
                    }
                    if (!writefind)
                    {
                        for (l = MAX_DEPTH - 1; l >= j; l--)
                        {
                            if (writeDlog[l].offset == (uint64_t)strtoull(match[5].str().c_str(), nullptr, 10))
                            {
                                Ctime.tv_sec = (__time_t)strtoull(match[1].str().c_str(), nullptr, 10);
                                Ctime.tv_nsec = (__syscall_slong_t)strtoull(match[2].str().c_str(), nullptr, 10);
                                Dtime.tv_sec = writeDlog[l].tv_sec;
                                Dtime.tv_nsec = writeDlog[l].tv_nsec;

                                if (Ctime.tv_nsec - Dtime.tv_nsec >= 0)
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec;
                                    D2Ctime.tv_nsec = Ctime.tv_nsec - Dtime.tv_nsec;
                                }
                                else
                                {
                                    D2Ctime.tv_sec = Ctime.tv_sec - Dtime.tv_sec - 1;
                                    D2Ctime.tv_nsec = 1000000000 + Ctime.tv_nsec - Dtime.tv_nsec;
                                }

                                strout = "";
                                strout += double_to_string(Dtime.tv_sec + (double)Dtime.tv_nsec / (double)1000000000) + " ";
                                // strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + " " +readDlog[l].workload + "\n";
                                strout += double_to_string(D2Ctime.tv_sec * 1000000 + (double)D2Ctime.tv_nsec / (double)1000) + "\n";
                                writeoutput.write(strout.c_str(), strout.length());

                                writefind = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    trace.close();
    readoutput.close();
    writeoutput.close();

    return 0;
}
