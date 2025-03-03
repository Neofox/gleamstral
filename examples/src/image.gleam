import file_streams/file_stream
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env

// To run this example:
// gleam run -m image 

// Helper function to extract content from AssistantMessage
fn extract_assistant_content(msg: message.Message) -> String {
  case msg {
    message.AssistantMessage(content, _, _) -> content
    _ -> "Unexpected message type"
  }
}

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.get_string("MISTRAL_API_KEY")

  // Create a new client
  let client = client.new(api_key)

  let base64 = image_to_base64("image.png")
  let messages =
    [
      message.user(
        message.MultiContent([
          message.Text("Please tell me the string on the box."),
          message.ImageUrl("data:image/png;base64," <> base64),
        ]),
      ),
    ]
    |> result.values

  let response = client.chat_completion(client, model.Pixtral, messages)

  case response {
    Ok(res) -> {
      let assert Ok(choice) = list.first(res.choices)
      // Use the helper function to extract content
      let content = extract_assistant_content(choice.message)

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
