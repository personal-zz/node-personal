#export everything from ./lib/personal-app
for key,val of require "./lib/personal-app"
    exports[key] = val
