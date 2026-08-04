// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

Turbo.config.drive.progressBarDelay = 200

// Console easter egg — cornucopia (horn of plenty), a symbol of abundance
console.log(`
     .-"""-.
   .'  🌽🍇  '.
  /  🍎🥕🍊🍇  \
  \   ~~~~~~~   /
   '.__________.'
    Tá Justo?
`)
console.log(
  "%cLiked what you saw? Visit my website — https://gustavoneiva.dev",
  "font-size:14px;color:#035925;font-weight:bold"
)
