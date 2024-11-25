from dataclasses import dataclass, field
from typing import Literal


Action = Literal["destroy", "format", "mount"]

EMPTY_DESCRIPTION = "__empty__"


@dataclass
class Step:
    action: Action  # Which action the step belongs to
    commands: list[list[str]]  # List of commands to execute
    description: str  # Explanatory message to display to the user

    @classmethod
    def empty(cls, action: Action) -> "Step":
        return cls(action, [], EMPTY_DESCRIPTION)

    def is_empty(self) -> bool:
        return self.commands == [] and self.description == EMPTY_DESCRIPTION


@dataclass
class Plan:
    actions: set[Action]
    steps: list[Step] = field(default_factory=list)
    skipped_steps: list[Step] = field(default_factory=list)

    def extend(self, other: "Plan") -> None:
        # For now I don't see a usecase for merging plans with action sets.
        assert self.actions == other.actions

        self.steps.extend(other.steps)
        self.skipped_steps.extend(other.skipped_steps)

    def append(self, step: Step) -> None:
        if step.is_empty():
            return

        if step.action in self.actions:
            self.steps.append(step)
        else:
            self.skipped_steps.append(step)
