# gleamstral

[![Package Version](https://img.shields.io/hexpm/v/gleamstral)](https://hex.pm/packages/gleamstral)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamstral/)

A Gleam client library for the Mistral AI API, providing type-safe access to Mistral's powerful language models, embeddings, and agents.

## Overview

Gleamstral enables Gleam applications to seamlessly integrate with Mistral AI's capabilities, including:

- Chat completions with various Mistral models (Large, Small, Ministral, etc.)
- Function/tool calling support
- Embeddings generation
- Agent API integration
- Image analysis with Pixtral models

Further documentation can be found at <https://hexdocs.pm/gleamstral>.

## Installation

```sh
gleam add gleamstral
```

## Getting an API key

You can get an API key **for free** from Mistral [La Plateforme](https://console.mistral.ai/).

## Quick Example

```gleam
import gleam/io
import gleam/httpc
import gleam/list
import gleamstral/client
import gleamstral/chat
import gleamstral/message
import gleamstral/model

pub fn main() {
  // Create a Mistral client with your API key
  let client = client.new("your-mistral-api-key")

  // Set up a chat with Mistral Large model
  let chat_client = chat.new(client) |> chat.set_temperature(0.7)

  // Define a list of one or many messages to send to the model
  let messages = [
    message.UserMessage(message.TextContent("Explain brievly what is Gleam")),
  ]

  // Send the request and get a response from the model
  let assert Ok(response) =
    chat_client
    |> chat.complete_request(model.MistralSmall, messages)
    |> httpc.send

  let assert Ok(response) = chat.handle_response(response)
  let assert Ok(choice) = list.first(response.choices)
  let assert message.AssistantMessage(content, _, _) = choice.message

  io.println("Response: " <> content) // "Gleam is a very cool language [...]"
}
```

## Key Features

### Chat Completions with Vision

Gleamstral supports multimodal inputs, allowing you to send both text and images to vision-enabled models like Pixtral:

```gleam
// Create a message with an image
let messages = [
  message.UserMessage(
    message.MultiContent([
      message.Text("What's in this image?"),
      message.ImageUrl("https://gleam.run/images/lucy/lucy.svg")
    ])
  )
]

// Use a Pixtral model for image analysis
let assert Ok(response) =
  chat.new(client)
  |> chat.complete_request(model.PixtralLarge, messages)
  |> httpc.send

let assert Ok(response) = chat.handle_response(response)
// Get the first choice from the response
let assert Ok(choice) = list.first(response.choices)
let assert message.AssistantMessage(content, _, _) = choice.message

io.println("Response: " <> content) // "This is a picture of the cute star lucy"
```

### Agent API

Access Mistral's Agent API to utilize pre-configured agents for specific tasks:

```gleam
// Get your agent ID from the Mistral console
let agent_id = "your-agent-id"

// Call the agent with your agent ID and messages
let assert Ok(response) =
  agent.new(client)
  |> agent.complete_request(agent_id, messages)
  |> httpc.send

let assert Ok(response) = agent.handle_response(response)
```

### Embeddings Generation

Generate vector embeddings for text to enable semantic search, clustering, or other vector operations:

```gleam
// Generate embeddings for a text input
let assert Ok(response) =
  embeddings.new(client)
  |> embeddings.create_request(model.MistralEmbed, ["Your text to embed"])
  |> httpc.send

let assert Ok(response) = embeddings.handle_response(response)
```

### Tool/Function Calling

Define tools that the model can use to call functions in your application:

```gleam
// Define a tool
let weather_tool = tool.new_basic_function(
  "get_weather",
  "Get the current weather in a location",
  [
    #("location", StringProperty("the name of the city")),
    #("unit", StringProperty("the unit to use for the temp. F or C"))
  ]
)

// Create a chat client with the tool
let assert Ok(response) =
  chat.new(client)
  |> chat.set_tools([weather_tool])
  |> chat.complete_request(model.MistralSmall, messages)
  |> httpc.send

let assert Ok(response) = chat.handle_response(response)
```

### Structured Outputs

Receive structured outputs from the model, based on a JSON schema:

```gleam
pub type Book {
  Book(name: String, authors: List(String))
}

fn book_decoder() -> blueprint.Decoder(Book) {
  blueprint.decode2(
    Book,
    blueprint.field("name", blueprint.string()),
    blueprint.field("authors", blueprint.list(blueprint.string())),
  )
}
let json_schema = blueprint.generate_json_schema(book_decoder())

// Create a chat client with structured output
let assert Ok(response) =
  chat.new(client)
  |> chat.set_response_format(chat.JsonSchema(
      schema: json_schema,
      name: "book",
    ))
  |> chat.complete_request(model.MistralSmall, messages)
  |> httpc.send
```

## Examples

The `examples/` directory contains several ready-to-use examples demonstrating the library's capabilities:

- `text_completion.gleam`: Basic text completion example
- `agent.gleam`: Shows how to use the Mistral Agent API
- `basic_tool.gleam`: Demonstrates tool/function calling functionality
- `embeddings.gleam`: Illustrates how to generate and use embeddings
- `image_analysis.gleam`: Shows how to perform image analysis with Pixtral models
- `json_object.gleam`: Example of JSON output from the model
- `structured_output.gleam`: Demonstrates how to use structured outputs

To run any example:

```sh
cd examples
gleam run -m example_name  # e.g., gleam run -m agent
```

Note: You'll need to set your Mistral API key in an `.env` file or as an environment variable.

## Roadmap

- [x] Decouple the HTTP client from the library
- [x] Add support for structured outputs (JSON, JSON Schema, etc.)
- [x] Improve tool calling support
- [ ] Add example for streaming responses
- [ ] Add more tests and documentation

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
