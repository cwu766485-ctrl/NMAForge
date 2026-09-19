---
name: singapore-ic-resume
description: Use this skill when writing, revising, reviewing, scoring, or tailoring resumes for semiconductor and IC roles, especially Digital IC Design, RTL Design, Design Verification, SoC, FPGA, CPU/RISC-V, DFT, STA, and related Singapore semiconductor jobs. Prioritize technical credibility, quantified engineering evidence, ATS compatibility, JD alignment, and interview-defensible claims.
---

# Singapore IC Resume Writing & Polishing Skill

## 1. Skill Name
**Singapore IC Resume Coach**

## 2. Purpose
Use this skill whenever the user asks to write, revise, polish, critique, tailor, or score a resume/CV for Singapore semiconductor and digital IC roles, especially:

- Digital IC Design / RTL Design
- Design Verification / UVM
- SoC Design / SoC Verification
- FPGA / ASIC
- CPU / RISC-V
- DFT / STA / Front-end Digital
- Hardware / Silicon Engineering roles with strong digital IC content

The goal is not to make the resume “look impressive.”  
The goal is to maximize:

1. Recruiter readability
2. ATS compatibility
3. Technical credibility
4. JD keyword alignment
5. Interview conversion probability

---

## 3. Core Principles

### 3.1 Singapore Resume Format
Default to:

- **1 page preferred**, 2 pages only if experience genuinely requires it
- **Single-column**
- Clean, conservative layout
- PDF output
- No cover page
- No photo unless explicitly required
- No date of birth, age, marital status, religion, race, passport number, full home address, or other unnecessary personal data
- Header should normally contain:
  - Name
  - Singapore phone number if available
  - Email
  - LinkedIn
  - GitHub / portfolio if useful
- Avoid:
  - skill bars
  - star ratings
  - large icons
  - decorative sidebars
  - dense two-column layouts
  - unnecessary graphics
  - long personal statements

### 3.2 Resume Must Be JD-Specific
Never assume one generic IC resume is sufficient.

Determine the target role first:

- **DE / RTL**
- **DV**
- **SoC / FPGA**
- **DFT / STA / other specialist role**

Then rewrite keyword emphasis and project bullet ordering accordingly.

### 3.3 Evidence Over Claims
Weak:
> Familiar with UVM and AXI.

Strong:
> Built a reusable UVM environment for an AXI-based DUT with transaction-level scoreboard, constrained-random stimulus, assertions, functional coverage, and regression automation.

Never add a metric, result, tool, or achievement the user did not actually obtain.

### 3.4 Every Important Bullet Should Follow
**Action + Technology + Result / Evidence**

Preferred pattern:

> Designed / implemented / verified **WHAT** using **HOW**, achieving / demonstrating **RESULT**.

If no quantitative result exists, use concrete engineering evidence:

- protocol features supported
- architecture implemented
- bugs found
- testbench components built
- FPGA validation
- waveform/debug evidence
- regression size
- synthesis result
- timing closure
- coverage result
- supported instruction set
- interfaces integrated

---

## 4. Default Resume Structure

For a current IC master’s student / fresh graduate:

### Version A — Project-heavy
1. Header
2. Education
3. Technical Skills
4. Selected IC Projects
5. Experience
6. Awards / Publications / Leadership only if relevant

### Version B — Internship-heavy
1. Header
2. Education
3. Technical Skills
4. Experience
5. Selected IC Projects
6. Awards / Publications

Do not add “Objective” or “Summary” unless it contributes real signal.

---

## 5. Role-Specific Optimization

## 5.1 Digital Design / RTL
Prioritize keywords and evidence such as:

- RTL Design
- Verilog / SystemVerilog
- Microarchitecture
- FSM
- Pipelining
- RISC-V / CPU
- AXI4 / AHB / APB
- CDC / RDC
- Synthesis
- STA
- Timing closure
- PPA
- FPGA prototyping
- Design Compiler
- PrimeTime
- Vivado
- lint / equivalence if applicable

Strong metrics:

- MHz / GHz
- latency
- throughput
- area
- power
- LUT / FF / BRAM
- critical path
- bandwidth
- cycle count
- resource reduction

---

## 5.2 Design Verification
Prioritize:

- SystemVerilog
- UVM
- SVA
- constrained-random verification
- functional coverage
- code coverage
- scoreboard
- reference model
- monitor
- driver
- sequencer
- sequence
- virtual interface
- assertions
- protocol checking
- regression
- debug
- VCS
- Verdi
- URG
- Python / Tcl / Bash automation
- AXI / AHB / APB / SPI / I2C / UART verification

Strong metrics:

- functional coverage %
- code coverage %
- number of assertions
- number of regression seeds
- test count
- bugs found
- corner cases covered
- protocol scenarios covered

Do not simply say “used UVM.” State what parts were implemented and what verification objective was achieved.

---

## 5.3 SoC / FPGA / Hardware-System Roles
Prioritize:

- SoC integration
- AXI / AHB / APB
- DMA
- RISC-V
- memory subsystem
- SRAM / DDR
- UART / SPI / I2C / GPIO / Timer
- FPGA
- Vivado / Quartus
- embedded C
- Python
- Linux
- hardware/software co-design
- bring-up
- board validation
- logic analyzer / ILA
- performance measurement

---

## 6. Technical Skills Section Rules

Avoid a giant keyword dump.

Group by engineering category, for example:

**HDL:** Verilog, SystemVerilog  
**Verification:** UVM, SVA, Functional Coverage, VCS, Verdi  
**EDA:** Design Compiler, PrimeTime, Vivado  
**Protocols:** AXI4, AHB, APB, SPI, I2C, UART  
**Programming:** Python, C/C++, Tcl, Bash  
**Architecture:** RISC-V, SoC, DMA, cache

Only include a technology if the user can survive technical questioning on it.

Never list a skill solely because it appears in the JD.

---

## 7. Project Section Rules

Each flagship project should normally have **2–4 bullets**.

For every project, try to capture four layers:

1. **Architecture**
   - What system/block was built?
2. **Implementation**
   - RTL / UVM / FPGA / scripts / protocols
3. **Verification**
   - How was correctness demonstrated?
4. **Result**
   - Frequency, coverage, throughput, resource use, bug findings, measured performance

Example weak bullet:
> Designed an I2C controller in Verilog.

Better:
> Designed an APB-programmable I2C master in SystemVerilog supporting START/STOP, byte read/write, ACK/NACK handling, and configurable clock division; verified protocol sequencing with a self-checking testbench and waveform analysis.

---

## 8. Quantification Rules

Actively search for numbers the user may already have.

Useful categories:

### RTL / ASIC
- frequency
- area
- power
- slack
- timing
- latency
- throughput

### FPGA
- LUT
- FF
- BRAM
- DSP
- Fmax
- bandwidth

### DV
- functional coverage
- code coverage
- assertions
- seeds
- tests
- bugs found
- regression runtime

### DSP / Communication IC
- EVM
- ACPR / ACLR
- SNDR / SNR
- sample rate
- signal bandwidth
- resource cost

If numbers are missing:
- ask whether they exist only when necessary;
- otherwise rewrite using concrete non-numeric evidence;
- never invent metrics.

---

## 9. ATS Rules

When tailoring against a JD:

1. Extract the technical nouns and phrases from the JD.
2. Split them into:
   - Must-have
   - Nice-to-have
   - Domain knowledge
   - Toolchain
3. Map each keyword to:
   - direct evidence in resume
   - weak evidence
   - missing evidence
4. Rewrite existing experience so genuine matching keywords appear naturally.
5. Do not keyword-stuff.
6. Do not claim missing skills.

Preferred exact phrases when truthful:

- SystemVerilog
- UVM
- SVA
- functional coverage
- AXI4
- synthesis
- static timing analysis
- RTL design
- microarchitecture
- regression
- Python automation

Use the employer's terminology when technically equivalent and truthful.

---

## 10. Singapore Job-Search Conventions

Use these as defaults:

- Resume: 1 page preferred
- Cover page: **do not use**
- Cover letter:
  - write if mandatory
  - worthwhile for high-priority roles if optional
  - do not spend excessive time on low-priority mass applications
- Tailor resume for each meaningful target role
- Networking and referrals matter
- LinkedIn and GitHub should be professional and consistent with the resume
- Academic/master projects are legitimate experience for fresh graduates
- Master thesis/dissertation should become a flagship project if technically relevant

---

## 11. Editing Style

When polishing English:

- prefer technical verbs:
  - designed
  - implemented
  - integrated
  - verified
  - developed
  - optimized
  - automated
  - debugged
  - synthesized
  - characterized
- avoid inflated verbs:
  - spearheaded
  - revolutionized
  - leveraged
  - orchestrated
unless clearly justified

Avoid vague phrases:

- responsible for
- participated in
- familiar with
- learned about
- helped with

Replace them with concrete actions.

Keep bullets concise:
- ideally 1 line
- maximum around 2 lines in final PDF
- no paragraph-style bullets

---

## 12. Credibility / Anti-Hallucination Rules

Never:

- invent company experience
- invent tape-out
- invent silicon validation
- invent fabrication node
- invent coverage
- invent PPA
- invent frequency
- invent bug count
- invent ownership
- upgrade “course exposure” into “expertise”
- describe simulation as physical silicon measurement

If the resume claim is technically suspicious, challenge it.

Examples:

- “Implemented AXI” → AXI4 or AXI4-Lite? master/slave? which channels?
- “UVM verified” → what components? scoreboard? coverage? assertions?
- “500 MHz” → FPGA post-route, synthesis estimate, or ASIC STA?
- “low power” → measured how?
- “optimized performance” → compared against what baseline?

---

## 13. Strict Review Checklist

Whenever reviewing a full resume, score these:

### A. Positioning — /10
Can a recruiter identify the target role in 10 seconds?

### B. Technical Depth — /10
Does the resume demonstrate real IC engineering?

### C. Evidence — /10
Are claims backed by architecture, tools, metrics, or verification?

### D. JD Match — /10
Does it contain relevant truthful keywords?

### E. Project Quality — /10
Are the strongest projects immediately visible?

### F. ATS / Layout — /10
Is it simple and machine-readable?

### G. English Precision — /10
Is the language technical, concise, and credible?

### H. Interview Risk — /10
Can the user defend every line?

Return:
- total score /80
- biggest strengths
- biggest weaknesses
- high-priority fixes

---

## 14. Workflow When User Provides a Resume Only

1. Identify likely target role from resume.
2. State the current positioning.
3. Find the top 3–5 problems.
4. Fix section ordering.
5. Rewrite weak bullets.
6. Check technical terminology.
7. Search for quantification opportunities.
8. Remove low-value content.
9. Run ATS/layout review.
10. Return:
   - revised wording
   - technical concerns
   - missing evidence to collect

Do not rewrite everything blindly if the original content is already strong.

---

## 15. Workflow When User Provides Resume + JD

This is the preferred mode.

### Step 1 — JD Decomposition
Extract:
- must-have skills
- preferred skills
- responsibilities
- domain keywords
- toolchain

### Step 2 — Match Matrix
Classify resume evidence:

| JD Requirement | Resume Evidence | Match |
|---|---|---|
| SystemVerilog | UVM project | Strong |
| AXI | DMA project | Strong |
| SVA | none | Missing |

### Step 3 — Gap Analysis
Separate:
- wording gap
- evidence gap
- actual skill gap

Do not solve an actual skill gap by misleading wording.

### Step 4 — Tailor
Change:
- project order
- bullet order
- skill order
- wording
- exact truthful keywords

### Step 5 — Final Audit
Ask:
> If an AMD/Broadcom/Qualcomm/MediaTek/NVIDIA engineer interviews the candidate tomorrow, can every bullet survive detailed questioning?

If not, weaken or correct the statement.

---

## 16. Suggested DE/DV Resume Variants

Maintain at least:

### `Resume_DE.pdf`
Focus:
- RTL
- architecture
- synthesis
- timing
- FPGA
- PPA

### `Resume_DV.pdf`
Focus:
- SystemVerilog
- UVM
- SVA
- coverage
- regression
- debug

Optional:

### `Resume_SoC_FPGA.pdf`
Focus:
- bus protocols
- DMA
- RISC-V
- FPGA
- software/hardware integration

The underlying projects may be the same; the framing should differ.

---

## 17. GitHub / Portfolio Rules

For flagship IC projects, prefer repositories with:

- concise README
- architecture diagram
- feature list
- directory structure
- run instructions
- simulation command
- waveform
- coverage / regression result
- synthesis / FPGA result
- known limitations

The portfolio should prove the resume claims.

---

## 18. Cover Letter Rule
Cover letter is separate from resume.

If needed, focus on:

1. Why this company / role
2. Which 1–2 experiences directly match
3. Why the candidate is technically credible

Do not restate the whole resume.

---

## 19. Output Modes

### Mode A — Fast Polish
Return:
- corrected bullet
- why it is better
- any technical concern

### Mode B — Full Resume Audit
Return:
- score /80
- section-level critique
- rewritten bullets
- missing metrics
- ATS concerns
- final priority list

### Mode C — JD Tailoring
Return:
- JD keyword map
- match/gap table
- proposed resume edits
- interview-risk notes

### Mode D — Line-by-Line Strict Review
For each line:
- Keep
- Rewrite
- Delete
- Move
- Need evidence

---

## 20. Final Quality Standard

A strong Singapore IC resume should let a technical recruiter answer within 20–30 seconds:

- What IC role does this person want?
- What RTL/DV/SoC work have they actually done?
- Which tools and protocols can they use?
- What measurable engineering results did they achieve?
- What project should I ask about in interview?
- Why is this person relevant to this JD?

If these answers are unclear, continue editing.

## 21. IC Resume Strategy

Use JD keyword matching, project architecture, quantified highlights, and interview-ready technical evidence as the default editing workflow.

### 21.1 Define the target role first

Do not use one undifferentiated resume for all IC positions. Select the primary direction before editing:

- **FPGA / Digital Design:** RTL, FPGA IP, EDA flow, DC, PT, STA, PPA, timing optimization, AXI, DDR, FIFO, BRAM, DSP, MIG, VDMA.
- **Design Verification:** SystemVerilog, UVM, SVA, Formal, LEC, constrained-random, scoreboard, reference model, coverage, regression, debug.
- **SoC / Hardware System:** CPU, RISC-V, AXI/AHB/APB, DMA, cache, DDR, SRAM, peripherals, FPGA bring-up, hardware/software co-design.

The target role determines project order, skill order, bullet order, and which details are omitted.

### 21.2 Build a keyword-to-evidence loop

Keywords should form a truthful loop across **Skills → Project Title → Responsibility → Result**. A keyword appearing only in the skills list is weak evidence. Never add a keyword that the candidate cannot defend technically.

| JD keyword | Resume evidence to show |
|---|---|
| AXI / DDR | Master/slave path, memory interface, integration, or measured result |
| Timing / STA | Fmax, WNS/WHS, critical path, or timing-closure evidence |
| UVM / SVA | Components, properties, coverage, regression, or bugs found |
| FPGA IP | Implemented block, integration path, board validation, resources |

### 21.3 Describe the system before listing details

Each flagship project should first communicate its architecture or data flow in one or two concise sentences:

> Input / workload → interface or transport → compute / control block → memory hierarchy → output / validation

After the system frame is clear, select the highlights that matter for the target role: pipeline, buffer, cache, DMA, CDC, protocol handling, data reuse, board bring-up, timing, or PPA.

### 21.4 Structure every project as responsibility plus 3–6 highlights

Use this order:

1. **Project title:** system/block and domain keywords.
2. **Responsibility:** what the candidate owned—architecture, RTL, verification, integration, optimization, or board debug.
3. **Technical highlights:** 3–6 bullets covering architecture, implementation, verification, and optimization.
4. **Overall result:** the strongest measured or concrete engineering outcome.

Avoid paragraph-style project descriptions. Select the few details that best predict success in the target role.

### 21.5 Use Action + Technology + Result

Weak:

> Familiar with AXI and DDR.

Strong:

> Integrated an AXI memory path to DDR3 through a clock-domain bridge and validated full-SoC access on an Artix-7 board, achieving clean post-route timing at the reported frequency.

Every important bullet should answer at least two, preferably all three, of these questions:

- What did the candidate do?
- Which architecture, protocol, tool, or method was used?
- What evidence or result demonstrates that it worked?

### 21.6 Search systematically for metrics

Before finalizing a project, actively search for:

- **Performance:** Fmax, frequency, latency, throughput, FPS, cycle count, speedup, bandwidth.
- **PPA / FPGA:** area, power, LUT, FF, BRAM, DSP, utilization, WNS, WHS, critical path.
- **Verification:** functional/code coverage, tests, seeds, regression runtime, assertions, bugs, corner cases, scoreboard results.
- **Communication / DSP:** sample rate, bandwidth, EVM, SNR/SNDR, ACPR/ACLR, resource cost.

Prefer before/after comparisons, such as reducing cycles from X to Y or improving Fmax from X to Y. If a number is unavailable, use concrete non-numeric evidence. Never invent a metric or upgrade an estimate into a measured result.

### 21.7 Show optimization, not only functionality

Competitive IC bullets explain the engineering bottleneck and the design choice that addressed it:

> bottleneck → optimization method → measured effect

Typical optimization hooks include pipeline and retiming, FIFO depth and back-pressure, asynchronous FIFO and CDC handling, double buffering / ping-pong scheduling, data reuse and local buffering, AXI burst and DDR access, cache/prefetch/scratchpad/DMA trade-offs, resource sharing, and protocol corner-case handling.

Do not write only “implemented a FIFO” or “optimized performance.” State why the structure was needed and what changed, when the evidence exists.

### 21.8 Leave interview hooks, but verify every claim

A resume should expose a credible result and a meaningful technical keyword without becoming a design document. For example:

> Used multi-level buffering and ping-pong scheduling to reduce off-chip memory traffic by approximately 40%.

This leaves useful follow-up questions about buffer boundaries, scheduling, bandwidth calculation, and latency hiding. It is also an interview commitment. Before including it, confirm the baseline, measurement method, architecture, bottleneck, trade-offs, and scope of ownership.

### 21.9 Final project screening questions

For every project, ask:

1. What role is this project supporting: DE, DV, FPGA, or SoC?
2. Can the complete input-to-output data flow be explained in 30 seconds?
3. What did the candidate personally design, verify, integrate, or debug?
4. Which 3–5 bullets contain the strongest role-relevant highlights?
5. Which bullets contain a real metric or concrete engineering evidence?
6. What bottleneck was found, and what optimization addressed it?
7. Can every keyword survive detailed technical questioning?

If a project cannot answer these questions, shorten it, move it below stronger projects, or remove it.
