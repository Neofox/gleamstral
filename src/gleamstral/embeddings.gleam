import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleamstral/client
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

/// Creates an HTTP request for the Embeddings API endpoint
///
/// This function prepares a request to be sent to the Mistral AI Embeddings API.
/// It needs to be paired with an HTTP client to actually send the request,
/// and the response should be handled with client.handle_response using 
/// the appropriate decoder.
///
/// ### Example
///
/// ```gleam
/// // Create the request
/// let req = embeddings
///   |> embeddings.create_request(
///     model.EmbeddingMistral,
///     ["Text to embed", "Another text to embed"]
///   )
///
/// // Send the request with your HTTP client
/// use response <- result.try(http_client.send(req))
/// 
/// // Handle the response with the appropriate decoder
/// client.handle_response(response, using: embeddings.response_decoder())
/// ```
pub fn create_request(
  embeddings: Embeddings,
  model: model.Model,
  inputs: List(String),
) -> request.Request(String) {
  let body = body_encoder(embeddings, model, inputs) |> json.to_string

  request.new()
  |> request.set_method(http.Post)
  |> request.set_header("authorization", "Bearer " <> embeddings.client.api_key)
  |> request.set_header("content-type", "application/json")
  |> request.set_host(client.api_endpoint)
  |> request.set_path("/v1/embeddings")
  |> request.set_body(body)
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
