import gleam/dynamic/decode
import gleamstral/message

pub type Response {
  Response(
    id: String,
    object: String,
    created: Int,
    model: String,
    choices: List(ChatCompletionChoice),
    usage: Usage,
  )
}

pub type FinishReason {
  Stop
  Length
  ModelLength
  Err
  ToolCalls
}

pub type ChatCompletionChoice {
  ChatCompletionChoice(
    index: Int,
    message: message.Message,
    finish_reason: FinishReason,
  )
}

pub type Usage {
  Usage(prompt_tokens: Int, completion_tokens: Int, total_tokens: Int)
}

fn usage_decoder() -> decode.Decoder(Usage) {
  use prompt_tokens <- decode.field("prompt_tokens", decode.int)
  use completion_tokens <- decode.field("completion_tokens", decode.int)
  use total_tokens <- decode.field("total_tokens", decode.int)
  decode.success(Usage(prompt_tokens:, completion_tokens:, total_tokens:))
}

pub fn response_decoder() -> decode.Decoder(Response) {
  use id <- decode.field("id", decode.string)
  use object <- decode.field("object", decode.string)
  use created <- decode.field("created", decode.int)
  use model <- decode.field("model", decode.string)
  use choices <- decode.field(
    "choices",
    decode.list(chat_completion_choice_decoder()),
  )
  use usage <- decode.field("usage", usage_decoder())
  decode.success(Response(id:, object:, created:, model:, choices:, usage:))
}

fn chat_completion_choice_decoder() -> decode.Decoder(ChatCompletionChoice) {
  use index <- decode.field("index", decode.int)
  use message <- decode.field("message", message.message_decoder())
  use finish_reason <- decode.field("finish_reason", finish_reason_decoder())
  decode.success(ChatCompletionChoice(index:, message:, finish_reason:))
}

fn finish_reason_decoder() -> decode.Decoder(FinishReason) {
  use finish_reason <- decode.then(decode.string)
  case finish_reason {
    "stop" -> decode.success(Stop)
    "length" -> decode.success(Length)
    "model_length" -> decode.success(ModelLength)
    "error" -> decode.success(Err)
    "tool_calls" -> decode.success(ToolCalls)
    _ -> decode.failure(Stop, "Invalid finish reason")
  }
}
