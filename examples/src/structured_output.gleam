import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleamstral/chat
import gleamstral/client
import gleamstral/message
import gleamstral/model
import glenvy/dotenv
import glenvy/env
import jscheam/schema

// To run this example:
// cd examples && gleam run -m structured_output

pub type Book {
  Book(name: String, authors: List(String))
}

fn book_to_json_schema() -> json.Json {
  schema.object([
    schema.prop("name", schema.string())
      |> schema.description("The name of the book"),
    schema.prop("authors", schema.array(schema.string()))
      |> schema.pattern("^[A-Z][a-z]+ [A-Z][a-z]+$")
      |> schema.description(
        "The authors of the book, in the format 'First Last'",
      ),
  ])
  |> schema.disallow_additional_props
  |> schema.to_json
}

pub fn main() {
  let _ = dotenv.load()
  let assert Ok(api_key) = env.string("MISTRAL_API_KEY")

  // Create a new client
  let client = client.new(api_key)

  let messages = [
    message.SystemMessage(message.TextContent("Extract the book informations")),
    message.UserMessage(message.TextContent(
      "I recently read To Kill a Mockingbird by Harper Lee.",
    )),
  ]

  // Generate a JSON schema using the blueprint library
  // You can also make the schema by hand if you prefer and not use the blueprint library.
  let json_schema = book_to_json_schema()
  let assert Ok(response) =
    chat.new(client)
    |> chat.set_response_format(chat.JsonSchema(
      schema: json_schema,
      name: "book",
    ))
    |> chat.set_max_tokens(100)
    |> chat.complete_request(model.MistralSmall, messages)
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
