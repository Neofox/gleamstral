import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleamstral/client
import gleamstral/embeddings/response
import gleamstral/model

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
