import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleamstral/message.{type Message}
import gleamstral/model

const api_endpoint = "api.mistral.ai"

pub type Error {
  InvalidTemperature
  InvalidMaxTokens
  InvalidTopP
  InvalidRandomSeed
}

pub type Client {
  Client(
    api_key: String,
    temperature: Float,
    max_tokens: Int,
    top_p: Float,
    stream: Bool,
    stop: List(String),
    random_seed: Int,
  )
}

pub fn new(api_key: String) -> Client {
  Client(
    api_key: api_key,
    temperature: 1.0,
    max_tokens: 0,
    top_p: 1.0,
    stream: False,
    stop: [],
    random_seed: 0,
  )
}

pub fn set_temperature(
  client: Client,
  temperature: Float,
) -> Result(Client, Error) {
  case temperature >=. 0.0 && temperature <=. 1.5 {
    True -> Ok(Client(..client, temperature:))
    False -> Error(InvalidTemperature)
  }
}

pub fn set_max_tokens(client: Client, max_tokens: Int) -> Result(Client, Error) {
  case max_tokens >= 0 {
    True -> Ok(Client(..client, max_tokens:))
    False -> Error(InvalidMaxTokens)
  }
}

pub fn set_top_p(client: Client, top_p: Float) -> Result(Client, Error) {
  case top_p >=. 0.0 && top_p <=. 1.0 {
    True -> Ok(Client(..client, top_p:))
    False -> Error(InvalidTopP)
  }
}

pub fn set_stop(client: Client, stop: List(String)) -> Result(Client, Error) {
  Ok(Client(..client, stop:))
}

pub fn set_random_seed(
  client: Client,
  random_seed: Int,
) -> Result(Client, Error) {
  case random_seed >= 0 {
    True -> Ok(Client(..client, random_seed:))
    False -> Error(InvalidRandomSeed)
  }
}

pub fn set_stream(client: Client, stream: Bool) -> Client {
  Client(..client, stream:)
}

pub fn chat_completion(
  client: Client,
  model: model.Model,
  messages: List(Message),
) -> Result(String, String) {
  let body = make_body(model, messages)

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> client.api_key)
    |> request.set_header("content-type", "application/json")
    |> request.set_host(api_endpoint)
    |> request.set_path("/v1/chat/completions")
    |> request.set_body(body)

  case httpc.send(request) {
    Ok(response) -> Ok(response.body)
    Error(err) -> {
      io.debug(err)
      Error("Error sending request")
    }
  }
}

fn make_body(model: model.Model, messages: List(Message)) -> String {
  json.object([
    #("model", json.string(model.to_string(model))),
    #(
      "messages",
      json.array(messages, of: fn(msg: Message) { message.to_json(msg) }),
    ),
  ])
  |> json.to_string
}
