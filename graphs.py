import re
import sys
import collections

try:
    import pygal
except ImportError:
    print('You need to install pygal.')
    sys.exit(1)

if len(sys.argv) != 2:
    print('Usage: %s results.txt' % sys.argv[0])
    sys.exit(1)

r = re.compile('^([^ ]+) +([^ ]+) +([0-9:.]+)')
allocs = collections.defaultdict(lambda: collections.defaultdict(dict))

with open(sys.argv[1]) as f:
    for l in f.readlines():
        match = r.search(l)
        if not match:
            continue
        test_name = match.group(1)
        alloc_name = match.group(2)
        time_split = match.group(3).split(':')
        time_taken = 0
        if len(time_split) == 2:
            time_taken = int(time_split[0]) * 60 + float(time_split[1])
        else:
            time_taken = float(time_split[0])
        allocs[test_name][alloc_name] = time_taken

for test_name, results in allocs.items():
    line_chart = pygal.Bar(logarithmic=True)
    line_chart.title = test_name + ' (in seconds)'
    for k, t in results.items():
        line_chart.add(k, t)
    with open('out-' + test_name + '.svg', 'wb') as f:
        f.write(line_chart.render())
