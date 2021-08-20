/*
Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2018 Carlo Capelli
*/

#ifndef FILE2STRING_H
#define FILE2STRING_H

#include <string>
#include <fstream>
#include <sstream>
#include <stdexcept>

std::string file2string(std::string path) {
    std::ifstream f(path);
    if (!f.good())
        throw std::invalid_argument(path + " not found");
    std::stringstream s;
    s << f.rdbuf();
    return s.str();
}

#endif // FILE2STRING_H
