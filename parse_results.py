#!/usr/bin/python3
import sys
import os.path
from time import sleep

def summarize(alloc):
	print("{} TOTAL: {:.3}s CPU ovhd ({:>.2%}), {:>8.2f} MB MEM ovhd ({:>.2%})".format( \
		alloc, \
		cpu_total[alloc] - cpu_total['sys'], \
		(cpu_total[alloc] - cpu_total['sys']) / cpu_total['sys'], \
		(mem_total[alloc] - mem_total['sys'])/1024, \
		(mem_total[alloc] - mem_total['sys']) / mem_total['sys']))

if len(sys.argv) < 2:
	print("I need a file to parse!")
	exit(1)

if not os.path.isfile(sys.argv[1]):
	print("File not found:", sys.argv[1], "assuming it's still being written, spinning");

while not os.path.isfile(sys.argv[1]):
	sleep(.1)

results = dict()

with open(sys.argv[1], 'r') as f:
	for line in f:
		line = line.split()
		bench = line[0]
		alloc = line[1]
		time = line[2]
		rss = line[3]
		if bench not in results:
			try:
				results[bench] = {alloc : [1, float(time),  float(rss)]}
			except ValueError:
				print("a line could not be parsed:\n", line, "assuming the next line is invalid")
				print(next(f, None))
				continue
		else:
			if alloc not in results[bench]:
				try:
					results[bench].update({alloc: [1, float(time), float(rss)]})
				except ValueError:
					print("a line could not be parsed:\n", line, "assuming the next line is invalid")
					print(next(f, None))
					continue
			else:
				results[bench][alloc][0] += 1
				try:
					results[bench][alloc][1] += float(time)
					results[bench][alloc][2] += float(rss)
				except ValueError:
					print("a line could not be parsed:\n", line, "assuming the next line is invalid")
					print(next(f, None))
					continue
	mem_total = dict()
	cpu_total = dict()
	for bench in results:
		try:
			baseline_cpu = results[bench]['sys'][1] / results[bench]['sys'][0]
			baseline_mem = results[bench]['sys'][2] / results[bench]['sys'][0]
		except KeyError:
			print("sys not found in allocs for benchmark:", bench)
			print(results[bench])
			exit(1)
		for alloc in results[bench]:
			if alloc not in mem_total:
				mem_total.update({alloc:0})
			if alloc not in cpu_total:
				cpu_total.update({alloc:0})
			cpu = results[bench][alloc][1] / results[bench][alloc][0]
			mem = results[bench][alloc][2] / results[bench][alloc][0]
			mem_total[alloc] += mem
			cpu_total[alloc] += cpu
#			if alloc == 'sys':
#				continue
			print("{:>14}\t{}\tCPU {:>6.2f}s ovhd {:>7.2%} MEM {:>9.1f} kB ovhd {:>8.2%} ({:>8.2f}s, {:>8} kB)".format(bench, alloc, cpu, (cpu / baseline_cpu) - 1, mem, (mem / baseline_mem) - 1, cpu - baseline_cpu, int(mem - baseline_mem)))
	for alloc in cpu_total:
		if alloc == "sys":
			continue
		summarize(alloc)
