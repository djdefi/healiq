# HealIQ Development Roadmap

## Current Status: Mature Development Phase (v0.0.7)

HealIQ has **exceeded its original MVP goals** and currently implements a comprehensive healing assistance system. Both Milestone 1 (MVP) and Milestone 2 (Visual & Config Enhancements) are complete.

---

## 🎯 Next Development Phase: External Integrations

### **Release 0.1.0: DBM/BigWigs Integration**
**Target:** Q4 2024 | **Effort:** 2-3 weeks | **Priority:** HIGH

**Features:**
- [ ] Hook into DBM/BigWigs encounter events
- [ ] Anticipate damage phases and adjust suggestion priorities
- [ ] Add encounter-specific rule modifications
- [ ] Configuration for integration sensitivity

**Technical Implementation:**
- Monitor DBM_CORE and BigWigs event system
- Create encounter detection framework in `Tracker.lua`
- Add encounter-aware rules to `Engine.lua`
- UI indicators for encounter-enhanced suggestions

**User Value:** Proactive healing suggestions before predictable damage spikes

---

### **Release 0.1.5: WeakAura Export**
**Target:** Q1 2025 | **Effort:** 2-3 weeks | **Priority:** MEDIUM-HIGH

**Features:**
- [ ] Export current suggestion as WeakAura string
- [ ] Export queue display as WeakAura group
- [ ] Real-time WA updates based on HealIQ engine
- [ ] Configuration for WA export format options

**Technical Implementation:**
- Create WA string generation in `Config.lua`
- Add export commands to slash command system
- Implement WA update hooks from `Engine.lua`
- UI export button in options frame

**User Value:** Integration with existing WeakAura setups for power users

---

## 🚀 Future Development: Multi-Spec & Advanced Features

### **Release 0.2.0: Multi-Spec Framework**
**Target:** Q2 2025 | **Effort:** 4-6 weeks | **Priority:** MEDIUM

**Features:**
- [ ] Abstract rule system for spec-agnostic engine
- [ ] Holy Priest baseline implementation
- [ ] Spec detection and auto-switching
- [ ] Spec-specific configuration profiles

**Technical Implementation:**
- Refactor `Engine.lua` with spec abstraction layer
- Create spec-specific rule modules
- Extend `Core.lua` spec detection
- UI spec selection and configuration

**User Value:** Expand addon usefulness to all healing specs

---

### **Release 0.2.5: Hybrid DPS Support (Catweaving)**
**Target:** Q3 2025 | **Effort:** 3-4 weeks | **Priority:** MEDIUM

**Features:**
- [ ] DPS spell suggestions for Restoration Druids
- [ ] Form switching recommendations (Cat/Moonkin)
- [ ] Mana efficiency calculations
- [ ] Hybrid mode toggle and configuration

**Technical Implementation:**
- Extend rule system with DPS context in `Engine.lua`
- Add form detection to `Tracker.lua`
- Create hybrid-specific UI indicators
- Balance mode configuration options

**User Value:** Support for advanced hybrid healing/DPS playstyles

---

## 🔬 Advanced Features (Long-term)

### **Release 0.3.0: Performance Analytics**
**Target:** Q4 2025 | **Effort:** 3-4 weeks | **Priority:** LOW-MEDIUM

**Features:**
- [ ] Suggestion accuracy tracking
- [ ] Healing effectiveness analytics
- [ ] Performance reporting and insights
- [ ] Rule optimization recommendations

### **Release 0.3.5: Community Features**
**Target:** Q1 2026 | **Effort:** 4-6 weeks | **Priority:** LOW

**Features:**
- [ ] Configuration sharing system
- [ ] Community rule profiles
- [ ] Online configuration repository
- [ ] Social features and leaderboards

---

## 📋 Development Guidelines

### **Code Standards**
- Maintain SafeCall error handling pattern
- Document all new functions with inline comments
- Update CHANGELOG.md for all releases
- Follow existing modular architecture

### **Testing Requirements**
- Lua syntax validation via GitHub Actions
- Manual testing on current WoW client
- Backward compatibility with saved variables
- Performance regression testing

### **Release Process**
1. Feature development in separate branch
2. Code review and testing
3. Version bump via GitHub Actions
4. Automated release package creation
5. Update documentation and changelog

---

## 💡 Feature Ideas Backlog

**Quality of Life Improvements:**
- Audio notifications for priority suggestions
- Keybind integration for suggested spells
- Custom spell priority configurations
- Advanced filtering and blacklist options

**Integration Opportunities:**
- Details! meter integration for damage prediction
- Raid frame addon compatibility
- Mythic+ dungeon specific suggestions
- PvP healing mode adaptations

**Advanced Rule System:**
- Machine learning for personalized suggestions
- Guild/raid specific rule profiles
- Seasonal/patch specific optimizations
- Advanced cooldown coordination

---

## 🎯 Success Metrics

**Release 0.1.0 Success Criteria:**
- DBM integration working in 5+ encounters
- User feedback rating > 4.0/5.0
- No performance regression from baseline

**Release 0.2.0 Success Criteria:**
- Holy Priest rules achieving feature parity
- Multi-spec user adoption > 25% of user base
- Successful configuration migration

**Long-term Success Metrics:**
- User retention > 80% after 3 months
- Community configuration sharing adoption
- Integration with 3+ major healing addons

---

*This roadmap is subject to change based on user feedback, WoW patch updates, and development capacity. Priority levels may be adjusted based on community needs and technical constraints.*