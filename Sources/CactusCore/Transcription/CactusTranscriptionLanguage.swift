// MARK: - CactusTranscriptionLanguage

/// A language code used to configure transcription prompts.
///
/// This type stores the raw short code expected by Whisper-style prompt tokens
/// (for example, `"en"` for English).
public struct CactusTranscriptionLanguage: RawRepresentable, Hashable, Sendable, Codable {
  /// The raw language code (for example, `"en"`).
  public var rawValue: String

  /// Creates a transcription language from a raw language code.
  ///
  /// - Parameter rawValue: A short language code such as `"en"` or `"fr"`.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

// MARK: - Supported Languages

extension CactusTranscriptionLanguage {
  /// Afrikaans language code.
  public static let afrikaans = Self(rawValue: "af")
  /// Albanian language code.
  public static let albanian = Self(rawValue: "sq")
  /// Amharic language code.
  public static let amharic = Self(rawValue: "am")
  /// Arabic language code.
  public static let arabic = Self(rawValue: "ar")
  /// Armenian language code.
  public static let armenian = Self(rawValue: "hy")
  /// Assamese language code.
  public static let assamese = Self(rawValue: "as")
  /// Azerbaijani language code.
  public static let azerbaijani = Self(rawValue: "az")
  /// Bashkir language code.
  public static let bashkir = Self(rawValue: "ba")
  /// Belarusian language code.
  public static let belarusian = Self(rawValue: "be")
  /// Bengali language code.
  public static let bengali = Self(rawValue: "bn")
  /// Bosnian language code.
  public static let bosnian = Self(rawValue: "bs")
  /// Breton language code.
  public static let breton = Self(rawValue: "br")
  /// Bulgarian language code.
  public static let bulgarian = Self(rawValue: "bg")
  /// Catalan language code.
  public static let catalan = Self(rawValue: "ca")
  /// Chinese language code.
  public static let chinese = Self(rawValue: "zh")
  /// Croatian language code.
  public static let croatian = Self(rawValue: "hr")
  /// Czech language code.
  public static let czech = Self(rawValue: "cs")
  /// Danish language code.
  public static let danish = Self(rawValue: "da")
  /// Dutch language code.
  public static let dutch = Self(rawValue: "nl")
  /// English language code.
  public static let english = Self(rawValue: "en")
  /// Esperanto language code.
  public static let esperanto = Self(rawValue: "eo")
  /// Estonian language code.
  public static let estonian = Self(rawValue: "et")
  /// Faroese language code.
  public static let faroese = Self(rawValue: "fo")
  /// Finnish language code.
  public static let finnish = Self(rawValue: "fi")
  /// French language code.
  public static let french = Self(rawValue: "fr")
  /// Galician language code.
  public static let galician = Self(rawValue: "gl")
  /// Georgian language code.
  public static let georgian = Self(rawValue: "ka")
  /// German language code.
  public static let german = Self(rawValue: "de")
  /// Greek language code.
  public static let greek = Self(rawValue: "el")
  /// Gujarati language code.
  public static let gujarati = Self(rawValue: "gu")
  /// Haitian Creole language code.
  public static let haitianCreole = Self(rawValue: "ht")
  /// Hausa language code.
  public static let hausa = Self(rawValue: "ha")
  /// Hawaiian language code.
  public static let hawaiian = Self(rawValue: "haw")
  /// Hebrew language code.
  public static let hebrew = Self(rawValue: "he")
  /// Hindi language code.
  public static let hindi = Self(rawValue: "hi")
  /// Hungarian language code.
  public static let hungarian = Self(rawValue: "hu")
  /// Icelandic language code.
  public static let icelandic = Self(rawValue: "is")
  /// Indonesian language code.
  public static let indonesian = Self(rawValue: "id")
  /// Irish language code.
  public static let irish = Self(rawValue: "ga")
  /// Italian language code.
  public static let italian = Self(rawValue: "it")
  /// Japanese language code.
  public static let japanese = Self(rawValue: "ja")
  /// Javanese language code.
  public static let javanese = Self(rawValue: "jw")
  /// Kannada language code.
  public static let kannada = Self(rawValue: "kn")
  /// Kazakh language code.
  public static let kazakh = Self(rawValue: "kk")
  /// Khmer language code.
  public static let khmer = Self(rawValue: "km")
  /// Korean language code.
  public static let korean = Self(rawValue: "ko")
  /// Lao language code.
  public static let lao = Self(rawValue: "lo")
  /// Latin language code.
  public static let latin = Self(rawValue: "la")
  /// Latvian language code.
  public static let latvian = Self(rawValue: "lv")
  /// Lingala language code.
  public static let lingala = Self(rawValue: "ln")
  /// Lithuanian language code.
  public static let lithuanian = Self(rawValue: "lt")
  /// Luxembourgish language code.
  public static let luxembourgish = Self(rawValue: "lb")
  /// Macedonian language code.
  public static let macedonian = Self(rawValue: "mk")
  /// Malagasy language code.
  public static let malagasy = Self(rawValue: "mg")
  /// Malay language code.
  public static let malay = Self(rawValue: "ms")
  /// Malayalam language code.
  public static let malayalam = Self(rawValue: "ml")
  /// Maltese language code.
  public static let maltese = Self(rawValue: "mt")
  /// Maori language code.
  public static let maori = Self(rawValue: "mi")
  /// Marathi language code.
  public static let marathi = Self(rawValue: "mr")
  /// Mongolian language code.
  public static let mongolian = Self(rawValue: "mn")
  /// Nepali language code.
  public static let nepali = Self(rawValue: "ne")
  /// Norwegian language code.
  public static let norwegian = Self(rawValue: "no")
  /// Norwegian Nynorsk language code.
  public static let norwegianNynorsk = Self(rawValue: "nn")
  /// Occitan language code.
  public static let occitan = Self(rawValue: "oc")
  /// Pashto language code.
  public static let pashto = Self(rawValue: "ps")
  /// Persian language code.
  public static let persian = Self(rawValue: "fa")
  /// Polish language code.
  public static let polish = Self(rawValue: "pl")
  /// Portuguese language code.
  public static let portuguese = Self(rawValue: "pt")
  /// Punjabi language code.
  public static let punjabi = Self(rawValue: "pa")
  /// Romanian language code.
  public static let romanian = Self(rawValue: "ro")
  /// Russian language code.
  public static let russian = Self(rawValue: "ru")
  /// Sanskrit language code.
  public static let sanskrit = Self(rawValue: "sa")
  /// Serbian language code.
  public static let serbian = Self(rawValue: "sr")
  /// Shona language code.
  public static let shona = Self(rawValue: "sn")
  /// Sindhi language code.
  public static let sindhi = Self(rawValue: "sd")
  /// Sinhala language code.
  public static let sinhala = Self(rawValue: "si")
  /// Slovak language code.
  public static let slovak = Self(rawValue: "sk")
  /// Slovenian language code.
  public static let slovenian = Self(rawValue: "sl")
  /// Somali language code.
  public static let somali = Self(rawValue: "so")
  /// Spanish language code.
  public static let spanish = Self(rawValue: "es")
  /// Sundanese language code.
  public static let sundanese = Self(rawValue: "su")
  /// Swahili language code.
  public static let swahili = Self(rawValue: "sw")
  /// Swedish language code.
  public static let swedish = Self(rawValue: "sv")
  /// Tagalog language code.
  public static let tagalog = Self(rawValue: "tl")
  /// Tajik language code.
  public static let tajik = Self(rawValue: "tg")
  /// Tamil language code.
  public static let tamil = Self(rawValue: "ta")
  /// Tatar language code.
  public static let tatar = Self(rawValue: "tt")
  /// Telugu language code.
  public static let telugu = Self(rawValue: "te")
  /// Thai language code.
  public static let thai = Self(rawValue: "th")
  /// Tibetan language code.
  public static let tibetan = Self(rawValue: "bo")
  /// Turkish language code.
  public static let turkish = Self(rawValue: "tr")
  /// Turkmen language code.
  public static let turkmen = Self(rawValue: "tk")
  /// Ukrainian language code.
  public static let ukrainian = Self(rawValue: "uk")
  /// Urdu language code.
  public static let urdu = Self(rawValue: "ur")
  /// Uzbek language code.
  public static let uzbek = Self(rawValue: "uz")
  /// Vietnamese language code.
  public static let vietnamese = Self(rawValue: "vi")
  /// Welsh language code.
  public static let welsh = Self(rawValue: "cy")
  /// Yiddish language code.
  public static let yiddish = Self(rawValue: "yi")
  /// Yoruba language code.
  public static let yoruba = Self(rawValue: "yo")
  /// Zulu language code.
  public static let zulu = Self(rawValue: "zu")
}
