import gleam/dynamic/decode

pub const api_endpoint = "api.mistral.ai"

pub type Error {
  RateLimitExceeded
  Unauthorized
  Unknown(String)
}

pub type Client {
  Client(api_key: String)
}

pub fn new(api_key: String) -> Client {
  Client(api_key: api_key)
}

pub fn error_decoder() -> decode.Decoder(Error) {
  use error <- decode.field("message", decode.string)
  decode.success(Unknown(error))
}
