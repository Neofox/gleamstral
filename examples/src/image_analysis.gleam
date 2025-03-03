import file_streams/file_stream
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// gleam run -m image_analysis 

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

  let response = client.chat_completion(client, model.Pixtral, messages)

  case response {
    Ok(res) -> {
      let assert Ok(choice) = list.first(res.choices)

      io.println("Response: " <> extract_content(choice.message))
      io.println(extract_usage(res.usage))
    }
    Error(error) -> {
      io.println("Error: " <> error)
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

fn extract_content(msg: message.Message) -> String {
  case msg {
    message.AssistantMessage(content, _, _) -> content
    _ -> "Unexpected message type"
  }
}

fn extract_usage(res: client.Usage) -> String {
  "Usage: completion_tokens: "
  <> int.to_string(res.completion_tokens)
  <> " prompt_tokens: "
  <> int.to_string(res.prompt_tokens)
  <> " total_tokens: "
  <> int.to_string(res.total_tokens)
}
