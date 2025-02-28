import gleam/io
import gleam/result
import gleamstral/client
import gleamstral/message
import gleamstral/model

// To run this example:
// gleam run -m examples/example 

const api_key = "Your API Key Here"

pub fn main() {
  // Create a new client
  let client =
    client.new(api_key)
    |> client.with_temperature(0.7)
    |> client.with_max_tokens(150)
    |> client.with_response_format(client.JsonObject)

  let messages =
    [
      message.system(message.TextContent(
        "You should only respond in JSON format. with the following keys: 'country', 'capital'",
      )),
      message.user(message.TextContent("What is the capital of France?")),
    ]
    |> result.values

  let response = client.chat_completion(client, model.MistralSmall, messages)

  case response {
    Ok(result) -> io.println("Response: " <> result)
    Error(error) -> io.println("Error: " <> error)
  }
}
