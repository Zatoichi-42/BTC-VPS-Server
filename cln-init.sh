# 1. CPU: count cores and show model
echo "=== CPU ==="
lscpu | awk -F: '/^CPU\(s\)/{print "Cores:", $2} /^Model name/{print "Model:", $2}'

# 2. Memory: total RAM & swap
echo
echo "=== Memory ==="
free -h

# 3. Disk: available space on /var (where your heavy data will live) and on your home dir
echo
echo "=== Disk (/var & $HOME) ==="
df -h /var $HOME

# 4. Inodes: ensure you’re not running out of filesystem inodes
echo
echo "=== Inodes ==="
df -i /var $HOME

# 5. FD limit: how many file descriptors your shell can open
echo
echo "=== File descriptor limit ==="
ulimit -n

# 6. Load: current load averages
echo
echo "=== Load average ==="
uptime
