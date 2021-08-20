/*
Description: list data structure

Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2017,2018 Carlo Capelli
*/
const {List,list} = require('./list-es6.js')
const tr = console.log

const i = List.iota(2)
tr(i.copy().to(), i.len(), i.slice(1).concat(List.iota(6)).toArray())
tr(i.concat(i).to())

let [x, y] = [List.iota(6), List.iota(6)]
tr(y.len(), y.len(2), y.to())

tr(y.len(3, x => 0), y.to(), y.map((x, y) => x + y).to())
tr((new List).len(3, x => 77).map((x, y) => x + y).to())

tr(List.from([1,2,3]).to('hello '))
