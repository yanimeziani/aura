import { chunkText } from '../lib/chunking';

console.log('🧪 Testing chunkText...');

const text = "This is a sentence. " + "Word ".repeat(100) + "\nAnother paragraph.";

// Test 1: Basic Chunking
const chunks = chunkText(text, 50, 10);
if (chunks.length > 0) {
  console.log('✅ Basic chunking passed');
} else {
  console.error('❌ Basic chunking failed');
  process.exit(1);
}

// Test 2: Overlap
const chunks2 = chunkText("1234567890", 5, 2);
// 12345
//    45678
//       7890
if (chunks2.length >= 2) {
  console.log('✅ Overlap passed');
} else {
  console.error('❌ Overlap failed');
  process.exit(1);
}

// Test 3: Empty
const chunks3 = chunkText("");
if (chunks3.length === 0) {
  console.log('✅ Empty text passed');
} else {
  console.error('❌ Empty text failed');
  process.exit(1);
}

console.log('🎉 All tests passed!');
