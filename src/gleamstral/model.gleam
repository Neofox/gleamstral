pub type Model {
  MistralLarge
  MistralSmall
  Ministral3B
  Ministral8B
  PixtralLarge
  Pixtral
}

pub fn to_string(model: Model) -> String {
  case model {
    MistralLarge -> "mistral-large-latest"
    MistralSmall -> "mistral-small-latest"
    Ministral3B -> "ministral-3b-latest"
    Ministral8B -> "ministral-8b-latest"
    PixtralLarge -> "pixtral-large-latest"
    Pixtral -> "pixtral-12b-2409"
  }
}
