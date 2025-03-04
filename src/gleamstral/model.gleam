import gleam/dynamic/decode

pub type Model {
  MistralLarge
  MistralSmall
  Ministral3B
  Ministral8B
  PixtralLarge
  Pixtral
  MistralEmbed
  MistralNemo
}

pub fn to_string(model: Model) -> String {
  case model {
    MistralLarge -> "mistral-large-latest"
    MistralSmall -> "mistral-small-latest"
    Ministral3B -> "ministral-3b-latest"
    Ministral8B -> "ministral-8b-latest"
    PixtralLarge -> "pixtral-large-latest"
    Pixtral -> "pixtral-12b-2409"
    MistralEmbed -> "mistral-embed"
    MistralNemo -> "open-mistral-nemo"
  }
}

pub fn model_decoder() -> decode.Decoder(Model) {
  use model <- decode.then(decode.string)
  case model {
    "mistral-large-latest" -> decode.success(MistralLarge)
    "mistral-small-latest" -> decode.success(MistralSmall)
    "ministral-3b-latest" -> decode.success(Ministral3B)
    "ministral-8b-latest" -> decode.success(Ministral8B)
    "pixtral-large-latest" -> decode.success(PixtralLarge)
    "pixtral-12b-2409" -> decode.success(Pixtral)
    "mistral-embed" -> decode.success(MistralEmbed)
    "open-mistral-nemo" -> decode.success(MistralNemo)
    _ -> decode.failure(MistralLarge, "Invalid model")
  }
}
