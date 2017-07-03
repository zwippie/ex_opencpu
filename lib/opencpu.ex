defmodule OpenCPU do
  defmodule AccessDenied,               do: defexception [:message]
  defmodule BadRequest,                 do: defexception [:message]
  defmodule InternalServerError,        do: defexception [:message]
  defmodule OpenCPUError,               do: defexception [:message]
  defmodule ResponseNotAvailableError,  do: defexception [:message]
  defmodule UnsupportedFormatError,     do: defexception [:message]
end
