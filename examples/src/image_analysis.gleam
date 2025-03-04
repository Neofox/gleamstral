import file_streams/file_stream
import gleam/bit_array
import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// cd examples && gleam run -m image_analysis 

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a new client
  let client = client.new(api_key)

  let base64 = image_to_base64("image.png")
  let messages = [
    message.UserMessage(
      message.MultiContent([
        message.Text("Please tell me the string on the box."),
        message.ImageUrl("data:image/png;base64," <> base64),
      ]),
    ),
  ]

  let assert Ok(response) =
    chat.new(client)
    |> chat.set_max_tokens(200)
    |> chat.complete_request(model.Pixtral, messages)
    |> httpc.send

  case chat.handle_response(response) {
    Ok(res) -> {
      let assert Ok(choice) = list.first(res.choices)
      let assert message.AssistantMessage(content, _, _) = choice.message

      io.println("Response: " <> content)
      io.println(
        "Usage: completion_tokens: "
        <> int.to_string(res.usage.completion_tokens)
        <> " prompt_tokens: "
        <> int.to_string(res.usage.prompt_tokens)
        <> " total_tokens: "
        <> int.to_string(res.usage.total_tokens),
      )
    }
    Error(error) -> {
      case error {
        client.RateLimitExceeded -> io.println("Rate limit exceeded")
        client.Unauthorized -> io.println("Unauthorized")
        client.Unknown(error) -> io.println("Unknown error: " <> error)
      }
    }
  }
}

pub fn image_to_base64(path: String) -> String {
  let assert Ok(stream) = file_stream.open_read(path)
  let content = read_until_eof(stream, <<>>)
  let _ = file_stream.close(stream)

  bit_array.base64_encode(content, True)
}

fn read_until_eof(stream, acc: BitArray) -> BitArray {
  case file_stream.read_bytes(stream, 4096) {
    Ok(chunk) -> read_until_eof(stream, bit_array.append(acc, chunk))
    Error(_) -> acc
  }
}
