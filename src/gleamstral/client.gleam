import gleam/dynamic/decode
import gleam/http/response
import gleam/json

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

/// Creates a new Mistral AI client with the provided API key and HTTP client
///
/// ## Example
///
/// ```gleam
/// // Using gleam_httpc
/// import gleam_httpc
/// let client = client.new("your-api-key-here", httpc.send)
/// 
/// // Or using another HTTP client, like gleam_hackney
/// import hackney
/// let client = client.new("your-api-key-here", hackney.send)
/// ```
pub fn new(api_key: String) -> Client {
  Client(api_key: api_key)
}

pub fn error_decoder() -> decode.Decoder(Error) {
  use error <- decode.field("message", decode.string)
  decode.success(Unknown(error))
}

/// Handle HTTP responses from the Mistral AI API
///
/// Takes a response and a decoder, and returns either the decoded response
/// or an appropriate error.
///
/// The generic type parameters allow this function to work with different
/// request and response types.
pub fn handle_response(
  response: response.Response(String),
  using decoder: decode.Decoder(response_type),
) -> Result(response_type, Error) {
  case response.status {
    200 -> {
      case json.parse(from: response.body, using: decoder) {
        Ok(decoded_response) -> Ok(decoded_response)
        Error(_) -> Error(Unknown("Failed to decode response"))
      }
    }
    429 -> Error(RateLimitExceeded)
    401 -> Error(Unauthorized)
    _ -> {
      case json.parse(from: response.body, using: error_decoder()) {
        Ok(error) -> Error(error)
        Error(_) -> Error(Unknown(response.body))
      }
    }
  }
}
