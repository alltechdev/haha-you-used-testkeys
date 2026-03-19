/*
 * Copyright (C) 2016 The Android Open Source Project
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "avb_unittest_util.h"

#include <android-base/file.h>

std::string mem_to_hexstring(const uint8_t* data, size_t len) {
  std::string ret;
  char digits[17] = "0123456789abcdef";
  for (size_t n = 0; n < len; n++) {
    ret.push_back(digits[data[n] >> 4]);
    ret.push_back(digits[data[n] & 0x0f]);
  }
  return ret;
}

std::string string_trim(const std::string& str) {
  size_t first = str.find_first_not_of(" \t\n");
  if (first == std::string::npos) {
    return str;
  }
  size_t last = str.find_last_not_of(" \t\n");
  return str.substr(first, (last - first + 1));
}

namespace avb {

void BaseAvbToolTest::SetUp() {
  /* Change current directory to test executable directory so that relative path
   * references to test dependencies don't rely on being manually run from
   * correct directory */
  ASSERT_TRUE(chdir(android::base::GetExecutableDirectory().c_str()) == 0);

  /* Create temporary directory to stash images in. */
  char* buf = strdup("/tmp/libavb-tests.XXXXXX");
  ASSERT_TRUE(mkdtemp(buf) != nullptr);
  testdir_ = buf;
  free(buf);

  /* Reset memory leak tracing */
  avb::testing_memory_reset();
}

void BaseAvbToolTest::TearDown() {
  /* Nuke temporary directory. */
  ASSERT_EQ(0U, testdir_.string().find("/tmp/libavb-tests"));
  ASSERT_TRUE(
      base::DeleteFile(base::FilePath(testdir_.c_str()), true /* recursive */));
  /* Ensure all memory has been freed. */
  EXPECT_TRUE(avb::testing_memory_all_freed());
}

std::string BaseAvbToolTest::CalcVBMetaDigest(const std::string& vbmeta_image,
                                              const std::string& digest_alg) {
  std::filesystem::path vbmeta_path = testdir_ / vbmeta_image;
  std::filesystem::path vbmeta_digest_path = testdir_ / "vbmeta_digest";
  EXPECT_COMMAND(
      0,
      "./avbtool.py calculate_vbmeta_digest --image %s --hash_algorithm %s"
      " --output %s",
      vbmeta_path.c_str(),
      digest_alg.c_str(),
      vbmeta_digest_path.c_str());
  std::string vbmeta_digest_data;
  EXPECT_TRUE(android::base::ReadFileToString(vbmeta_digest_path.string(),
                                              &vbmeta_digest_data));
  return string_trim(vbmeta_digest_data);
}

void BaseAvbToolTest::GenerateVBMetaImage(
    const std::string& image_name,
    const std::string& algorithm,
    uint64_t rollback_index,
    const std::string& key_path,
    const std::string& additional_options) {
  std::string signing_options;
  if (algorithm == "") {
    signing_options = " --algorithm NONE ";
  } else {
    signing_options =
        std::string(" --algorithm ") + algorithm + " --key " + key_path + " ";
  }
  vbmeta_image_path_ = testdir_ / image_name;
  EXPECT_COMMAND(0,
                 "./avbtool.py make_vbmeta_image"
                 " --rollback_index %" PRIu64
                 " %s %s "
                 " --output %s",
                 rollback_index,
                 additional_options.c_str(),
                 signing_options.c_str(),
                 vbmeta_image_path_.c_str());
  int64_t file_size;
  ASSERT_TRUE(base::GetFileSize(base::FilePath(vbmeta_image_path_.c_str()),
                                &file_size));
  vbmeta_image_.resize(file_size);
  ASSERT_TRUE(base::ReadFile(base::FilePath(vbmeta_image_path_.c_str()),
                             reinterpret_cast<char*>(vbmeta_image_.data()),
                             vbmeta_image_.size()));
}

/* Generate a file with name |file_name| of size |image_size| with
 * known content (0x00 0x01 0x02 .. 0xff 0x00 0x01 ..).
 */
std::string BaseAvbToolTest::GenerateImage(const std::string file_name,
                                           size_t image_size,
                                           uint8_t start_byte) {
  std::filesystem::path image_path = testdir_ / file_name;
  EXPECT_COMMAND(0,
                 "./avbtool.py generate_test_image "
                 "--image_size %d "
                 "--start_byte %d "
                 "--output %s",
                 image_size,
                 start_byte,
                 image_path.c_str());
  base::File::Info stats;
  EXPECT_TRUE(base::GetFileInfo(base::FilePath(image_path.c_str()), &stats));
  EXPECT_EQ((size_t)stats.size, image_size);
  return image_path.string();
}

std::string BaseAvbToolTest::InfoImage(const std::string& image_path) {
  std::filesystem::path tmp_path = testdir_ / "info_output.txt";
  EXPECT_COMMAND(0,
                 "./avbtool.py info_image --image %s --output %s",
                 image_path.c_str(),
                 tmp_path.c_str());
  std::string info_data;
  EXPECT_TRUE(android::base::ReadFileToString(tmp_path.string(), &info_data));
  return info_data;
}

std::string BaseAvbToolTest::PublicKeyAVB(const std::string& key_path) {
  std::filesystem::path tmp_path = testdir_ / "public_key.bin";
  EXPECT_COMMAND(0,
                 "./avbtool.py extract_public_key --key %s"
                 " --output %s",
                 key_path.c_str(),
                 tmp_path.c_str());
  std::string key_data;
  EXPECT_TRUE(android::base::ReadFileToString(tmp_path.string(), &key_data));
  return key_data;
}

std::string BaseAvbToolTest::PublicKeyAVBDigest(const std::string& key_path) {
  std::filesystem::path tmp_path = testdir_ / "public_key_digest";
  EXPECT_COMMAND(0,
                 "./avbtool.py extract_public_key_digest --key %s"
                 " --output %s",
                 key_path.c_str(),
                 tmp_path.c_str());
  std::string digest_data;
  EXPECT_TRUE(android::base::ReadFileToString(tmp_path.string(), &digest_data));
  return digest_data;
}

}  // namespace avb
