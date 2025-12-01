#!/usr/bin/env lua

package.path = package.path .. ';src/?.lua;src/?/init.lua'

local lnko = require('lnko')
lnko.main(arg)
