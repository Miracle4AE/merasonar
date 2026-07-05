from __future__ import annotations



import json

from dataclasses import dataclass

from typing import Any, Dict, Mapping



from ai_assistant.captain_atlas import (

    captain_atlas_scope_task,

    captain_atlas_system_prompt,

)

from ai_assistant.config import AiAssistantConfig





@dataclass(frozen=True)

class PromptBundle:

    system_prompt: str

    user_prompt: str

    prompt_version: str





class AiAssistantPromptBuilder:

    """System/user prompt üretimi — tüm scope'lar Captain Atlas persona kullanır."""



    def __init__(self, config: AiAssistantConfig) -> None:

        self._config = config



    @property

    def prompt_version(self) -> str:

        return self._config.prompt_version



    def build(

        self,

        context: Mapping[str, Any],

        *,

        repair_hint: str | None = None,

    ) -> PromptBundle:

        system = captain_atlas_system_prompt(prompt_version=self.prompt_version)

        user = self._user_prompt(context, repair_hint=repair_hint)

        return PromptBundle(

            system_prompt=system,

            user_prompt=user,

            prompt_version=self.prompt_version,

        )



    def _user_prompt(

        self,

        context: Mapping[str, Any],

        *,

        repair_hint: str | None,

    ) -> str:

        scope = str(context.get("scope", "session_summary"))

        payload = json.dumps(dict(context), ensure_ascii=False, indent=2)

        task = captain_atlas_scope_task(scope, context)

        parts = [

            f"prompt_version: {self.prompt_version}",

            f"Görev kapsamı: {scope}",

            task,

            "Analiz bağlamı (JSON):",

            payload,

        ]

        if repair_hint:

            parts.extend(["", "Onarım talimatı:", repair_hint])

        return "\n".join(parts)


