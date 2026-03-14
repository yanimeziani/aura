export function chunkText(text: string, chunkSize = 1000, chunkOverlap = 200): string[] {
  const chunks: string[] = [];
  let startIndex = 0;

  while (startIndex < text.length) {
    let endIndex = startIndex + chunkSize;
    
    // If not at the end of text, try to find a newline or space to break at
    if (endIndex < text.length) {
      const lastSpace = text.lastIndexOf(' ', endIndex);
      const lastNewline = text.lastIndexOf('\n', endIndex);
      const breakPoint = Math.max(lastSpace, lastNewline);
      
      if (breakPoint > startIndex) {
        endIndex = breakPoint;
      }
    } else {
      endIndex = text.length;
    }

    chunks.push(text.slice(startIndex, endIndex).trim());
    startIndex = endIndex - chunkOverlap;
    
    // Ensure we actually progress
    if (startIndex <= 0 || startIndex >= text.length || endIndex >= text.length) {
      if (endIndex >= text.length) break;
      startIndex = endIndex; // Force progress if overlap is too big
    }
  }

  return chunks.filter(c => c.length > 0);
}
