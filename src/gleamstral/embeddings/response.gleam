import gleam/dynamic/decode

pub type Response {
  Response(
    id: String,
    object: String,
    data: List(EmbeddingData),
    model: String,
    usage: Usage,
  )
}

pub fn response_decoder() -> decode.Decoder(Response) {
  use id <- decode.field("id", decode.string)
  use object <- decode.field("object", decode.string)
  use data <- decode.field("data", decode.list(embedding_data_decoder()))
  use model <- decode.field("model", decode.string)
  use usage <- decode.field("usage", usage_decoder())
  decode.success(Response(id:, object:, data:, model:, usage:))
}

pub type EmbeddingData {
  EmbeddingData(index: Int, embedding: List(Float))
}

fn embedding_data_decoder() -> decode.Decoder(EmbeddingData) {
  use index <- decode.field("index", decode.int)
  use embedding <- decode.field("embedding", decode.list(decode.float))
  decode.success(EmbeddingData(index:, embedding:))
}

pub type Usage {
  Usage(prompt_tokens: Int, total_tokens: Int)
}

fn usage_decoder() -> decode.Decoder(Usage) {
  use prompt_tokens <- decode.field("prompt_tokens", decode.int)
  use total_tokens <- decode.field("total_tokens", decode.int)
  decode.success(Usage(prompt_tokens:, total_tokens:))
}
