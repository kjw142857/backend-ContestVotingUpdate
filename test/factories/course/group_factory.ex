defmodule Cadet.Courses.GroupFactory do
  @moduledoc """
  Factory for Group entity
  """

  defmacro __using__(_opts) do
    quote do
      alias Cadet.Courses.Group

      def group_factory do
        %Group{
          name: sequence("group"),
          leader: build(:user, role: :staff)
        }
      end
    end
  end
end
