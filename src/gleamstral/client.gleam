import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleamstral/message.{type Message, type MessageContent}
import gleamstral/model

const api_endpoint = "api.mistral.ai"

pub type Client {
  Client(api_key: String, temperature: Float, max_tokens: Int, top_p: Float)
}

pub fn new(api_key: String) -> Client {
  Client(api_key: api_key, temperature: 1.0, max_tokens: 1000, top_p: 1.0)
}

pub fn chat_completion(
  client: Client,
  model: model.Model,
  messages: List(Message(MessageContent)),
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

  io.debug(request)
  case httpc.send(request) {
    Ok(response) -> Ok(response.body)
    Error(err) -> {
      io.debug(err)
      Error("Error sending request")
    }
  }
}

fn make_body(
  model: model.Model,
  messages: List(Message(MessageContent)),
) -> String {
  json.object([
    #("model", json.string(model.to_string(model))),
    #(
      "messages",
      json.array(messages, of: fn(msg: Message(MessageContent)) {
        message.to_json(msg)
      }),
    ),
  ])
  |> json.to_string
}
