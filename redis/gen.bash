#!/bin/bash
# used to regenerate cmd.go
set -e

filename="cmd.go"

if [ $# == 1 ]; then
    redis_h=$1
else
    redis_h=`locate redis.h | grep '/redis\.h$' | head -n 1`
fi

if [ ! -e "$redis_h" ]; then
    echo "usage: $0 path/to/redis.h"
    echo "(or make sure you have mlocate and redis-devel installed)"
    exit 1
fi

cmds=`cat $redis_h | egrep '^void ([a-z])*Command\(' | sed 's/void \([a-z]*\)Command.*/\1/'`
# for some reason, some commands arent in redis.h
cmds=("${cmds[@]}" "smembers")
# sort
cmds=($(printf "%s\n" "${cmds[@]}"|sort))
cat >$filename <<EOF
// Generated by gen.bash.
// DO NOT EDIT THIS FILE DIRECTLY!

package redis

// Cmd is a type for Redis command names.
type Cmd string

const (
EOF

# commands
for cmd in ${cmds[@]}; do
	echo "	cmd${cmd^} Cmd = \"${cmd^^}\"" >>$filename
done
echo -e ")
" >>$filename

# command calls
for cmd in ${cmds[@]}; do
    echo "
// ${cmd^} calls Redis ${cmd^^} command. 
func (c *Client) ${cmd^}(args ...interface{}) *Reply {
	return c.call(cmd${cmd^}, args...)
}" >>$filename
done

# async command calls
for cmd in ${cmds[@]}; do
    echo "
// Async${cmd^} calls Redis ${cmd^^} asynchronously. 
func (c *Client) Async${cmd^}(args ...interface{}) Future {
	return c.asyncCall(cmd${cmd^}, args...)
}" >>$filename
done

# multi command calls
for cmd in ${cmds[@]}; do
    echo "
// ${cmd^} queues a Redis ${cmd^^} command for later execution. 
func (mc *MultiCall) ${cmd^}(args ...interface{}) {
	mc.call(cmd${cmd^}, args...)
}" >>$filename
done

gofmt -tabs=true -tabwidth=4 -w $filename
