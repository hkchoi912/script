all:
	g++ -std=c++11 -O2 D2C_extractor.cc -DTIME_FACTOR=1 -o D2C_extractor -lrt -I /usr/bin/include -laio

debug:
	g++ -std=c++11 -O0 -g -rdynamic D2C_extractor.cc -DTIME_FACTOR=1 -o D2C_extractor -lrt -I /usr/bin/include -laio