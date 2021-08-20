/*
Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2018 Carlo Capelli
*/

#include "hhprolog.h"

namespace hhprolog {

    Prog::Prog(string s) : Engine(s) {
    }
    Prog::~Prog() {
    }

    void Prog::run(bool print_ans) {
        Int ctr = 0;
        for (;; ctr++) {
            auto A = ask();
            if (A.type == Object::t_null)
                break;
            if (print_ans)
                pp(cstr("[") + ctr + "] " + "*** ANSWER=" + showTerm(A));
        }
        pp(cstr("TOTAL ANSWERS=") + ctr);
    }

    void Prog::ppCode() {
        string t;
        for (size_t i = 0; i < syms.size(); i++) {
            if (i > 0) t += ", ";
            t += syms[i] + "=" + i;
        }
        pp("\nSYMS:\n{" + t + "}");

        pp("\nCLAUSES:\n");
        for (size_t i = 0; i < clauses.size(); i++) {
            auto C = clauses[i];
            pp(cstr("[") + i + "]:" + showClause(C));
        }
        pp("");
    }

    string Prog::showTerm(Object O) {
        if (O.type == Object::t_int)
            return Engine::showTerm(O.i);
        if (O.type == Object::t_vector)
            return st0(O.v);
        return O.toString();
    }

    string Prog::showClause(const Clause &s) {
        string r;

        Int l = Int(s.hgs.size());
        r += cstr("---base:[") + s.base + "] neck: " + s.neck + "-----\n";
        r += showCells2(s.base, s.len); // TODO
        r += "\n";
        r += showCell(s.hgs[0]);

        r += " :- [";
        for (Int i = 1; i < l; i++) {
            auto e = s.hgs[size_t(i)];
            r += showCell(e);
            if (i < l - 1)
                r += ", ";
        }
        r += "]\n";

        r += Engine::showTerm(s.hgs[0]);
        if (l > 1) {
            r += " :- \n";
            for (Int i = 1; i < l; i++) {
                auto e = s.hgs[size_t(i)];
                r += "  ";
                r += Engine::showTerm(e);
                r += "\n";
            }
        } else
            r += "\n";
        return r;
    }

    string Prog::st0(const vector<Object> &args) {
        string r;
        if (!args.empty()) {
            string name = args[0].toString();
            if (args.size() == 3 && isOp(name)) {
                r += "(";
                r += maybeNull(args[0]);
                r += " " + name + " ";
                r += maybeNull(args[1]);
                r += ")";
            } else if (args.size() == 3 && isListCons(name)) {
                r += '[';
                r += maybeNull(args[1]);
                Object tail = args[2];
                for (;;) {
                    if ("[]" == tail.toString() || "nil" == tail.toString())
                        break;
                    if (tail.type != Object::t_vector) {
                        r += '|';
                        r += maybeNull(tail);
                        break;
                    }
                    const vector<Object>& list = tail.v;
                    if (!(list.size() == 3 && isListCons(list[0].toString()))) {
                        r += '|';
                        r += maybeNull(tail);
                        break;
                    } else {
                        r += ',';
                        r += maybeNull(list[1]);
                        tail = list[2];
                    }
                }
                r += ']';
            } else if (args.size() == 2 && "$VAR" == name) {
                r += "_" + args[1].toString();
            } else {
                string qname = maybeNull(args[0]);
                r += qname;
                r += "(";
                for (size_t i = 1; i < args.size(); i++) {
                    r += maybeNull(args[i]);
                    if (i < args.size() - 1)
                        r += ",";
                }
                r += ")";
            }
        }
        return r;
    }

    string Prog::maybeNull(const Object &O) {
        if (O.type == Object::t_null)
            return "$null";
        if (O.type == Object::t_vector)
            return st0(O.v);
        return O.toString();
    }
}
