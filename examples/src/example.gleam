import gleam/io
import gleam/result
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// gleam run -m example 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a new client
  let client =
    client.new(api_key)
    |> client.set_temperature(0.7)
    |> client.set_max_tokens(150)
    |> client.set_response_format(client.JsonObject)

  let messages =
    [
      message.system(message.TextContent(
        "You should only respond in JSON format. with the following keys: 'country', 'capital'",
      )),
      message.user(message.TextContent("What is the capital of France?")),
    ]
    |> result.values

  let response = client.chat_completion(client, model.MistralSmall, messages)
  io.debug(response)
}
