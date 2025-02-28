import gleam/io
import gleam/result
import gleamstral/client
import gleamstral/message
import gleamstral/model

pub fn main() {
  let model = model.MistralSmall
  let messages =
    [
      message.new(
        message.User,
        message.MultiContent([
          message.Text("Hello, where is the nearest restaurant?"),
          message.Text("I'm hungry"),
        ]),
      ),
    ]
    |> result.values

  let client = client.new("Your API key here")
  let assert Ok(completion) = client.chat_completion(client, model, messages)

  io.println(completion)
}
