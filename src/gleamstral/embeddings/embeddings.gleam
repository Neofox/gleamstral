import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleamstral/client
import gleamstral/embeddings/response
import gleamstral/model

/// Represents an embeddings service with configuration options
///
/// Use this to generate vector embeddings for text inputs
pub type Embeddings {
  Embeddings(client: client.Client, config: Config)
}

pub type Config {
  Config(encoding_format: EncodingFormat)
}

/// Format of the generated embeddings
///
/// - `Float`: Standard floating point format for vector embeddings
pub type EncodingFormat {
  Float
}

fn encoding_format_encoder(encoding_format: EncodingFormat) -> json.Json {
  case encoding_format {
    Float -> json.string("float")
  }
}

pub fn set_encoding_format(
  embeddings: Embeddings,
  encoding_format: EncodingFormat,
) -> Embeddings {
  Embeddings(..embeddings, config: Config(encoding_format:))
}

fn default_config() -> Config {
  Config(encoding_format: Float)
}

/// Creates a new Embeddings instance with default configuration using the provided client
///
/// ### Example
///
/// ```gleam
/// let client = client.new("your-api-key")
/// let embeddings = embeddings.new(client)
/// ```
pub fn new(client: client.Client) -> Embeddings {
  Embeddings(client: client, config: default_config())
}

/// Generates embeddings for the provided text inputs
///
/// ### Parameters
///
/// - `embeddings`: The configured Embeddings instance
/// - `model`: The model to use for generating embeddings
/// - `inputs`: A list of text strings to generate embeddings for
///
/// ### Returns
///
/// - `Ok(response.Response)`: The successful response containing embeddings
/// - `Error(client.Error)`: An error that occurred during the request
///
/// ### Example
///
/// ```gleam
/// let result = embeddings.create(
///   embeddings,
///   model.EmbeddingMistral,
///   ["Text to embed", "Another text to embed"]
/// )
/// ```
pub fn create(
  embeddings: Embeddings,
  model: model.Model,
  inputs: List(String),
) -> Result(response.Response, client.Error) {
  let body = body_encoder(embeddings, model, inputs) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header(
      "authorization",
      "Bearer " <> embeddings.client.api_key,
    )
    |> request.set_header("content-type", "application/json")
    |> request.set_host(client.api_endpoint)
    |> request.set_path("/v1/embeddings")
    |> request.set_body(body)

  let assert Ok(http_result) = httpc.send(request)
  case http_result.status {
    200 -> {
      let assert Ok(response) =
        json.parse(from: http_result.body, using: response.response_decoder())
      Ok(response)
    }
    429 -> Error(client.RateLimitExceeded)
    401 -> Error(client.Unauthorized)
    _ -> {
      case json.parse(from: http_result.body, using: client.error_decoder()) {
        Ok(error) -> Error(error)
        Error(_) -> Error(client.Unknown(http_result.body))
      }
    }
  }
}

fn body_encoder(
  embeddings: Embeddings,
  model: model.Model,
  inputs: List(String),
) -> json.Json {
  json.object([
    #("model", json.string(model.to_string(model))),
    #("input", json.array(inputs, of: json.string)),
    #(
      "encoding_format",
      encoding_format_encoder(embeddings.config.encoding_format),
    ),
  ])
}
