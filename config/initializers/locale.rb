# I18n locale configuration
# This file is loaded during Rails initialization

# Set available locales
I18n.available_locales = [:de, :en]

# Set default locale
I18n.default_locale = :de

# Configure fallback behavior
# If a translation is missing in German, fall back to English, and vice versa
Rails.application.config.i18n.fallbacks = {
  de: [:de, :en],
  en: [:en, :de]
}
