defmodule Cadet.Incentives.Achievements do
  @moduledoc """
  Stores `Achievement`s.
  """
  use Cadet, [:context, :display]

  alias Cadet.Incentives.Achievement

  import Ecto.Query

  @doc """
  Returns all achievements.

  This returns Achievement structs with prerequisites and goal association maps pre-loaded.
  """
  @spec get(integer()) :: [Achievement.t()]
  def get(course_id) when is_ecto_id(course_id) do
    Achievement
    |> where(course_id: ^course_id)
    |> preload([:prerequisites, :goals])
    |> Repo.all()
  end

  @doc """
  Returns a user's total xp from their completed achievements.

  This returns Achievement structs with prerequisites, goal association and progress maps pre-loaded.
  """
  def achievements_total_xp(course_id, user_id) when is_ecto_id(course_id) do
    achievements =
      Achievement
      |> where(course_id: ^course_id)
      |> preload([:prerequisites, goals: [goal: [progress: :course_reg]]])
      |> Repo.all()

    is_goal_completed = fn goal_item ->
      if Enum.count(goal_item.goal.progress) != 0,
        do:
          Enum.at(goal_item.goal.progress, 0).completed and
            user_id == Enum.at(goal_item.goal.progress, 0).course_reg.user_id and
            Enum.at(goal_item.goal.progress, 0).count == goal_item.goal.meta["targetCount"],
        else: false
    end

    Enum.reduce(achievements, 0, fn achievement_item, acc ->
      completed_goals =
        if Enum.count(achievement_item.goals) != 0,
          do:
            Enum.reduce_while(achievement_item.goals, 1, fn goal_item, acc ->
              if is_goal_completed.(goal_item),
                do: {:cont, acc},
                else: {:halt, 0}
            end),
          else: 0

      acc + completed_goals * achievement_item.xp
    end)
  end

  @spec upsert(map()) :: {:ok, Achievement.t()} | {:error, {:bad_request, String.t()}}
  @doc """
  Inserts a new achievement, or updates it if it already exists.
  """
  def upsert(attrs) when is_map(attrs) do
    # course_id not nil check is left to the changeset
    case attrs[:uuid] || attrs["uuid"] do
      nil ->
        {:error, {:bad_request, "No UUID specified in Achievement"}}

      uuid ->
        Achievement
        |> preload([:prerequisites, :goals])
        |> Repo.get(uuid)
        |> (&(&1 || %Achievement{})).()
        |> Achievement.changeset(attrs)
        |> Repo.insert_or_update()
        |> case do
          result = {:ok, _} ->
            result

          {:error, changeset} ->
            {:error, {:bad_request, full_error_messages(changeset)}}
        end
    end
  end

  @spec upsert_many([map()]) :: {:ok, [Achievement.t()]} | {:error, {:bad_request, String.t()}}
  def upsert_many(many_attrs) when is_list(many_attrs) do
    Repo.transaction(fn ->
      for attrs <- many_attrs do
        case upsert(attrs) do
          {:ok, achievement} -> achievement
          {:error, error} -> Repo.rollback(error)
        end
      end
    end)
  end

  @doc """
  Deletes an achievement.
  """
  @spec delete(Ecto.UUID.t()) ::
          :ok | {:error, {:not_found, String.t()}}
  def delete(uuid) when is_binary(uuid) do
    case Achievement
         |> where(uuid: ^uuid)
         |> Repo.delete_all() do
      {0, _} -> {:error, {:not_found, "Achievement not found"}}
      {_, _} -> :ok
    end
  end
end
