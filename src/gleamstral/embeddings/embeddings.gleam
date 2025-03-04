import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleamstral/client
import gleamstral/embeddings/response
import gleamstral/model

const api_endpoint = "api.mistral.ai"

pub type Embeddings {
  Embeddings(client: client.Client, config: Config)
}

pub type Config {
  Config(encoding_format: EncodingFormat)
}

pub type EncodingFormat {
  Float
}

pub fn encoding_format_decoder() -> decode.Decoder(EncodingFormat) {
  use encoding_format <- decode.then(decode.string)
  case encoding_format {
    "float" -> decode.success(Float)
    _ -> decode.failure(Float, "Invalid encoding format")
  }
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

pub fn new(client: client.Client) -> Embeddings {
  Embeddings(client: client, config: default_config())
}

pub fn create(
  embeddings: Embeddings,
  model: model.Model,
  inputs: List(String),
) -> Result(response.Response, String) {
  let body = body_encoder(embeddings, model, inputs) |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header(
      "authorization",
      "Bearer " <> embeddings.client.api_key,
    )
    |> request.set_header("content-type", "application/json")
    |> request.set_host(api_endpoint)
    |> request.set_path("/v1/embeddings")
    |> request.set_body(body)

  let assert Ok(http_result) = httpc.send(request)
  case http_result.status {
    200 -> {
      let assert Ok(response) =
        json.parse(from: http_result.body, using: response.response_decoder())
      Ok(response)
    }
    _ -> {
      io.debug(http_result)
      case json.parse(from: http_result.body, using: error_decoder()) {
        Ok(error) -> Error(error)
        Error(_) -> Error(http_result.body)
      }
    }
  }
}

fn error_decoder() -> decode.Decoder(String) {
  use error <- decode.field("message", decode.string)
  decode.success(error)
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
