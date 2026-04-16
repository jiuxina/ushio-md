// Add this to main.js syncRenderedDom function for debugging
// Place after line 1494: const markdownImageSources = collectMarkdownImageSources(currentMarkdown);

// === DEBUG CODE START ===
console.log('[syncRenderedDom] Debug info:');
console.log('  currentMarkdown:', currentMarkdown.substring(0, 200));
console.log('  markdownImageSources:', markdownImageSources);
const domImages = Array.from(root.querySelectorAll('.ProseMirror img'));
console.log('  DOM images count:', domImages.length);
domImages.forEach((img, i) => {
  console.log(`    [${i}] src="${img.getAttribute('src')}" data-type="${img.getAttribute('data-type') || 'none'}"`);
});
// === DEBUG CODE END ===
