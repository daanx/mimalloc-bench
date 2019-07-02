@retained = []

STRING_SIZES = 5
LARGE_CHUNK_SIZES = 10
RAND = Random.new(SEED)
SEED=1


def stress(allocate_count, retain_count, chunk_size)
  chunk = []
  while retain_count > 0 || allocate_count > 0
    if retain_count == 0 || (RAND.rand < 0.5 && allocate_count > 0)
      chunk << " " * (10*RAND.rand(STRING_SIZES))
      allocate_count -= 1
      if chunk.length > chunk_size
        chunk = [" " * 10000 * LARGE_CHUNK_SIZES]
      end
    else
      @retained << " " * (10*RAND.rand(STRING_SIZES))
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
