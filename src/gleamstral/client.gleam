import gleam/dynamic/decode

pub const api_endpoint = "api.mistral.ai"

/// Represents possible errors that can occur when interacting with the Mistral AI API
///
/// - `RateLimitExceeded`: Returned when API rate limits have been reached
/// - `Unauthorized`: Returned when API key is invalid or missing
/// - `Unknown`: Returned for any other error, with the error message as a string
pub type Error {
  RateLimitExceeded
  Unauthorized
  Unknown(String)
}

/// Client for interacting with the Mistral AI API
///
/// Contains the API key required for authentication
pub type Client {
  Client(api_key: String)
}

/// Creates a new Mistral AI client with the provided API key
///
/// ## Example
///
/// ```gleam
/// let client = client.new("your-api-key-here")
/// ```
pub fn new(api_key: String) -> Client {
  Client(api_key: api_key)
}

pub fn error_decoder() -> decode.Decoder(Error) {
  use error <- decode.field("message", decode.string)
  decode.success(Unknown(error))
}
