@retained = []

STRING_UNIT=10
STRING_SIZES=5
LARGE_UNIT=1000
LARGE_CHUNK_SIZES = 100
SEED=1
RAND = Random.new(SEED)


def stress(allocate_count, retain_count, chunk_size)
  chunk = []
  while retain_count > 0 || allocate_count > 0
    if retain_count == 0 || (RAND.rand < 0.5 && allocate_count > 0)
      chunk << " " * (STRING_UNIT*RAND.rand(STRING_SIZES))
      allocate_count -= 1
      if chunk.length > chunk_size
        chunk = [" " * LARGE_UNIT * LARGE_CHUNK_SIZES]
      end
    else
      @retained << " " * (STRING_UNIT*RAND.rand(STRING_SIZES))
      retain_count -= 1
    end
  end
end

start = Time.now
threads = ARGV[0].to_i
if (threads==0) then threads = 1; end
puts "run with #{threads} threads"

(0...threads).map do
  Thread.new do
    stress(12_000_000/threads, 600_000/threads, 200_000/threads)
  end
end.each(&:join)

duration = (Time.now - start).to_f

# _, size = `ps ax -o pid,rss | grep -E "^[[:space:]]*#{$$}"`.strip.split.map(&:to_i)
# puts "#{size},#{duration}"
puts "duration: #{duration}"
