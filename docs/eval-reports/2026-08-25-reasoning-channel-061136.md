# Reasoning tokens by structured-output channel

Does asking for `json_schema` cost a model its reasoning? Each model answers the same A2 prompt through both channels; only the channel differs within a pair.

| | |
|---|---|
| started | 2026-08-25T06:11:36Z |
| commit | `4ae880e37920` |
| working tree | **DIRTY** - `scripts/probe_a2_panel.py`, `src/eval/sufficiency/judge.py`, `src/eval/sufficiency/llm.py`, `src/eval/sufficiency/stage_a.py`, `src/eval/sufficiency/stage_a1.py`, and 6 more |
| provider | `LlmServers.OPENROUTER` |
| temperature | 0 |
| reasoning effort | high |
| channels | `function_calling`, `json_schema` |
| cases | `gdpr_art7_case4`, `gdpr_art15_case1` |
| calls | 32 |
| per-call timeout | 120s |
| stage | `src/eval/sufficiency/stage_a2.py` |
| script | `scripts/probe_reasoning_channel.py` |

`—` is a call that reported no reasoning field; `0` is a call that reported spending nothing on reasoning; `no data` is a call that did not come back. The three are different findings.

Completed 2026-08-25T06:15:39Z.

## Reasoning tokens, paired

**gdpr_art7_case4**

| panelist | function_calling | json_schema | tools status | json_schema status |
|---|---:|---:|---|---|
| `DEEPSEEK_V_4_FLASH_0731` | 335 | no data | OK | TIMEOUT |
| `DEEPSEEK_V_4_PRO_0813` | 1183 | 2663 | OK | OK |
| `GEMINI_3_7_FLASH` | 695 | 603 | OK | OK |
| `GROK_4_6` | 1119 | 0 | OK | OK |
| `KIMI_K3` | 316 | 151 | OK | OK |
| `MINIMAX_M_3` | 632 | 156 | STRUCTURE | STRUCTURE |
| `QWEN_3_8_27B` | 598 | 257 | OK | OK |
| `QWEN_3_8_2_4T_A95B` | 733 | 622 | OK | OK |

**gdpr_art15_case1**

| panelist | function_calling | json_schema | tools status | json_schema status |
|---|---:|---:|---|---|
| `DEEPSEEK_V_4_FLASH_0731` | 400 | no data | OK | TIMEOUT |
| `DEEPSEEK_V_4_PRO_0813` | 930 | 0 | OK | OK |
| `GEMINI_3_7_FLASH` | 1712 | 1517 | OK | OK |
| `GROK_4_6` | 2455 | 2947 | OK | OK |
| `KIMI_K3` | 1368 | 460 | OK | OK |
| `MINIMAX_M_3` | 537 | 567 | STRUCTURE | STRUCTURE |
| `QWEN_3_8_27B` | 1156 | 1817 | OK | OK |
| `QWEN_3_8_2_4T_A95B` | 1332 | 1446 | OK | OK |

## Verdict per model

One run per cell, so only a categorical difference is claimed. See the module docstring on why a ratio is not a finding here.

| panelist | assigned channel | verdict | basis |
|---|---|---|---|
| `DEEPSEEK_V_4_FLASH_0731` | `function_calling` | inconclusive | no case reported reasoning on both channels |
| `DEEPSEEK_V_4_PRO_0813` | `function_calling` | SUPPRESSED | 1 of 2 comparable case(s) went to zero under json_schema |
| `GEMINI_3_7_FLASH` | `function_calling` | no suppression | both channels reported a positive count on all 2 comparable case(s) |
| `GROK_4_6` | `json_schema` | SUPPRESSED | 1 of 2 comparable case(s) went to zero under json_schema |
| `KIMI_K3` | `json_schema` | no suppression | both channels reported a positive count on all 2 comparable case(s) |
| `MINIMAX_M_3` | `json_schema` | no suppression | both channels reported a positive count on all 2 comparable case(s) |
| `QWEN_3_8_27B` | `function_calling` | no suppression | both channels reported a positive count on all 2 comparable case(s) |
| `QWEN_3_8_2_4T_A95B` | `function_calling` | no suppression | both channels reported a positive count on all 2 comparable case(s) |

## Every call

| case | panelist | channel | status | claims | reasoning | cost | generation |
|---|---|---|---|---:|---:|---:|---|
| gdpr_art7_case4 | `DEEPSEEK_V_4_FLASH_0731` | `function_calling` | OK | 2 | 335 | $0.000110 | `gen-1787638300-v5monFuIKd1LBJ6V9wPT` |
| gdpr_art7_case4 | `DEEPSEEK_V_4_FLASH_0731` | `json_schema` | TIMEOUT | — | no data | — | — |
| gdpr_art7_case4 | `DEEPSEEK_V_4_PRO_0813` | `function_calling` | OK | 2 | 1183 | $0.006735 | `gen-1787638301-ruRMbbmIILnnEl8pln4b` |
| gdpr_art7_case4 | `DEEPSEEK_V_4_PRO_0813` | `json_schema` | OK | 2 | 2663 | $0.013101 | `gen-1787638301-ZmSn2rkQ53VP9amZ7EJJ` |
| gdpr_art7_case4 | `GEMINI_3_7_FLASH` | `function_calling` | OK | 2 | 695 | $0.004298 | `gen-1787638301-V3QCCtGnCEKwoHklBMQt` |
| gdpr_art7_case4 | `GEMINI_3_7_FLASH` | `json_schema` | OK | 2 | 603 | $0.003788 | `gen-1787638301-odtZgf4xxLFvdNiMYTD8` |
| gdpr_art7_case4 | `GROK_4_6` | `function_calling` | OK | 2 | 1119 | $0.011864 | `gen-1787638300-aE7aDuUwr1ExoFUd6cXL` |
| gdpr_art7_case4 | `GROK_4_6` | `json_schema` | OK | 2 | 0 | $0.004374 | `gen-1787638301-9LsT1JfvormCcUEMAtA4` |
| gdpr_art7_case4 | `KIMI_K3` | `function_calling` | OK | 2 | 316 | $0.014039 | `gen-1787638301-KSxn1Ol1PPCgLcnZBbK1` |
| gdpr_art7_case4 | `KIMI_K3` | `json_schema` | OK | 2 | 151 | $0.008313 | `gen-1787638301-r0r5vQzBY4jADjdR725k` |
| gdpr_art7_case4 | `MINIMAX_M_3` | `function_calling` | STRUCTURE | — | 632 | $0.001336 | `gen-1787638301-8S7gpkjPIkdw5Ge0md7y` |
| gdpr_art7_case4 | `MINIMAX_M_3` | `json_schema` | STRUCTURE | — | 156 | $0.000644 | `gen-1787638301-58yYbLfFit2MakqaM4Kz` |
| gdpr_art7_case4 | `QWEN_3_8_27B` | `function_calling` | OK | 2 | 598 | $0.002651 | `gen-1787638300-mnlPnSlfzpK9TO5MYZDn` |
| gdpr_art7_case4 | `QWEN_3_8_27B` | `json_schema` | OK | 2 | 257 | $0.001982 | `gen-1787638301-LCBqjaDonuROtbvNGAMx` |
| gdpr_art7_case4 | `QWEN_3_8_2_4T_A95B` | `function_calling` | OK | 2 | 733 | $0.008234 | `gen-1787638301-ev4bwKXlY9z0emW1KeSw` |
| gdpr_art7_case4 | `QWEN_3_8_2_4T_A95B` | `json_schema` | OK | 2 | 622 | $0.008160 | `gen-1787638301-thNAyhvTuEw05XpZclXf` |
| gdpr_art15_case1 | `DEEPSEEK_V_4_FLASH_0731` | `function_calling` | OK | 10 | 400 | $0.000144 | `gen-1787638420-C69HcJUnZIrJ8ztMEkub` |
| gdpr_art15_case1 | `DEEPSEEK_V_4_FLASH_0731` | `json_schema` | TIMEOUT | — | no data | — | — |
| gdpr_art15_case1 | `DEEPSEEK_V_4_PRO_0813` | `function_calling` | OK | 10 | 930 | $0.005769 | `gen-1787638420-iIe50ZKkrZmul5BS43Hq` |
| gdpr_art15_case1 | `DEEPSEEK_V_4_PRO_0813` | `json_schema` | OK | 10 | 0 | $0.004011 | `gen-1787638420-P4tcXh88QKTtKEO5EA9U` |
| gdpr_art15_case1 | `GEMINI_3_7_FLASH` | `function_calling` | OK | 10 | 1712 | $0.009950 | `gen-1787638420-t9iyROuQT4yTSAsVMDMB` |
| gdpr_art15_case1 | `GEMINI_3_7_FLASH` | `json_schema` | OK | 10 | 1517 | $0.008851 | `gen-1787638420-Y20ZoM3Hmbv949ACHEdu` |
| gdpr_art15_case1 | `GROK_4_6` | `function_calling` | OK | 10 | 2455 | $0.022042 | `gen-1787638420-vz62EGbpLSmn7frI8Fug` |
| gdpr_art15_case1 | `GROK_4_6` | `json_schema` | OK | 10 | 2947 | $0.025436 | `gen-1787638420-azKgoNZqgcHRRrDbIWOm` |
| gdpr_art15_case1 | `KIMI_K3` | `function_calling` | OK | 13 | 1368 | $0.028515 | `gen-1787638420-XXH5cgeV7bApiv0ZRtwp` |
| gdpr_art15_case1 | `KIMI_K3` | `json_schema` | OK | 10 | 460 | $0.015558 | `gen-1787638420-VdQKbmriPGubY5JsNqt5` |
| gdpr_art15_case1 | `MINIMAX_M_3` | `function_calling` | STRUCTURE | — | 537 | $0.001481 | `gen-1787638420-vpo6Qo5ELcviNnsgLk93` |
| gdpr_art15_case1 | `MINIMAX_M_3` | `json_schema` | STRUCTURE | — | 567 | $0.001097 | `gen-1787638420-oSjd0RV5zbSzL8NvWwUF` |
| gdpr_art15_case1 | `QWEN_3_8_27B` | `function_calling` | OK | 10 | 1156 | $0.005069 | `gen-1787638420-eQpQvhnY3Alp4d739TBD` |
| gdpr_art15_case1 | `QWEN_3_8_27B` | `json_schema` | OK | 10 | 1817 | $0.007785 | `gen-1787638420-MP57cYPF27UFuQ5DOqTz` |
| gdpr_art15_case1 | `QWEN_3_8_2_4T_A95B` | `function_calling` | OK | 13 | 1332 | $0.014444 | `gen-1787638420-D99X3klRsLCzZDU4XWH3` |
| gdpr_art15_case1 | `QWEN_3_8_2_4T_A95B` | `json_schema` | OK | 10 | 1446 | $0.013410 | `gen-1787638420-WPF4X0Xl36nQSQ5Yn2Gf` |

**Spend: $0.253191** over 32 call(s); 2 returned no price.

## Calls that returned no claims

Kept because they still measured the channel — and because the cells where a channel misbehaves are the cells this probe is about.

- `DEEPSEEK_V_4_FLASH_0731` / gdpr_art7_case4 / `json_schema` [TIMEOUT] no response within 120s
- `MINIMAX_M_3` / gdpr_art7_case4 / `function_calling` [STRUCTURE] stage A2: the model's output would not coerce into its schema (None). It returned: claims: CORE - "No. The withdrawal of consent does not affect the lawfulness of processing that was based on consent 
- `MINIMAX_M_3` / gdpr_art7_case4 / `json_schema` [STRUCTURE] stage A2: the model's output would not coerce into its schema (OutputParserException('Invalid json output: \nFor troubleshooting, visit: https://docs.langchain.com/oss/python/langchain/errors/OUTPUT_P
- `DEEPSEEK_V_4_FLASH_0731` / gdpr_art15_case1 / `json_schema` [TIMEOUT] no response within 120s
- `MINIMAX_M_3` / gdpr_art15_case1 / `function_calling` [STRUCTURE] stage A2: the model's output would not coerce into its schema (None). It returned: claims: CORE - "The company must provide confirmation of processing." reason: One of the specific details the questio
- `MINIMAX_M_3` / gdpr_art15_case1 / `json_schema` [STRUCTURE] stage A2: the model's output would not coerce into its schema (OutputParserException('Invalid json output: \nFor troubleshooting, visit: https://docs.langchain.com/oss/python/langchain/errors/OUTPUT_P

