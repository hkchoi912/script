#include <iostream>
#include <fstream>
#include <string>
#include <regex>
#include <errno.h>

// Time in seconds, Action, Action, Offset, Length
std::regex regex_blkparse("\\d+,\\d+ +\\d+ +\\d+ +(\\d+)\\.(\\d+) +\\d+ +(\\w) +(\\w+) +(\\d+) \\+ (\\d+).*");

int main(int argc, char *argv[])
{
    char *tracepath = nullptr;
    char *outputpath = nullptr;

    std::ifstream trace;
    std::ofstream output;
    
    // Read device name, trace file and delay
    if (argc >= 3)
    {
        tracepath = argv[1];
        outputpath = argv[2];
    }
    if (argc < 3)
    {
        std::cerr << "parsing blktrace" << std::endl;
        std::cerr << "Invalid number of arguments." << std::endl;
        std::cerr << argv[0] << " <trace file> <output file>" << std::endl;
        return 1;
    }

    // Open trace file
    trace.open(tracepath);
    output.open(outputpath, std::ofstream::out | std::ofstream::trunc);     // open with delete contents

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
            if (match[3].str().at(0) == 'D')
            {
                char rwsb = match[4].str().at(0);
                // Check rwsb
                if (rwsb != 'R' && rwsb != 'W')
                {
                    continue;
                }
                output.write(match[0].str().c_str(), line.length());
                output.write("\n", 1);
            }
        }
    }

    return 0;
}
