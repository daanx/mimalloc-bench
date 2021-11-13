// Test allocation large blocks between 5 and 25 MiB with up to 20 live at any time.
// Provided by Leonid Stolyarov in issue #447 and modified by Daan Leijen.
#include <chrono>
#include <random>
#include <iostream>
#include <memory>

int main() {
  static constexpr int kNumBuffers = 20;
  static constexpr size_t kMinBufferSize = 5 * 1024 * 1024;
  static constexpr size_t kMaxBufferSize = 25 * 1024 * 1024;
  std::unique_ptr<char[]> buffers[kNumBuffers];

  //std::random_device rd;
  std::mt19937 gen(42); //rd());
  std::uniform_int_distribution<> size_distribution(kMinBufferSize, kMaxBufferSize);
  std::uniform_int_distribution<> buf_number_distribution(0, kNumBuffers - 1);

  static constexpr int kNumIterations = 2000;
  const auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < kNumIterations; ++i) {
    int buffer_idx = buf_number_distribution(gen);
    size_t new_size = size_distribution(gen);
    buffers[buffer_idx] = std::make_unique<char[]>(new_size);
  }
  const auto end = std::chrono::steady_clock::now();
  const auto num_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
  const auto us_per_allocation = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count() / kNumIterations;
  //std::cout << kNumIterations << " allocations Done in " << num_ms << "ms." << std::endl;
  //std::cout << "Avg " << us_per_allocation << " us per allocation" << std::endl;
  return 0;
}
