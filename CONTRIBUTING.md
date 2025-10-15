# Contributing to K8s Learning Path

Thanks for your interest in contributing! This guide will help you get started.

## How to Contribute

### Reporting Issues

Found an error or have a suggestion?
- Open an issue describing the problem or enhancement
- Include the module name and section
- For errors: include the command that failed and expected vs actual behavior

### Contributing Content

We welcome:
- Typo fixes and clarifications
- New exercises and examples
- Additional troubleshooting scenarios
- Updates for new Kubernetes versions
- Translations

### Guidelines

1. **Keep it practical**: Focus on hands-on, testable examples
2. **Test your changes**: Verify all commands work on a fresh cluster
3. **Follow the structure**: Match the style of existing modules
4. **Be beginner-friendly**: Explain concepts, don't assume knowledge
5. **Include validation**: Add steps to verify the exercise worked

### Module Structure

Each module should have:
```markdown
# Module Title

**Duration**: Estimated time
**Prerequisites**: What you need to know first
**Next Module**: Link to next module

## Learning Objectives
- ✅ Clear, measurable objectives

## Part 1: Concept
- Explanation
- Why it matters
- Example YAML
- Commands to run

## Hands-On Exercises
- Practical exercises
- Expected output
- Common mistakes

## Validation Checklist
- [ ] Can you do X?
- [ ] Can you do Y?

## Key Takeaways
- Summary points

## Additional Resources
- External links
```

### Style Guide

**Commands**:
```bash
# Always include comments
kubectl get pods

# Show expected output
# NAME       READY   STATUS    AGE
# web-123    1/1     Running   10s
```

**YAML**:
```yaml
# Include comments explaining non-obvious fields
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example
spec:
  replicas: 3  # High availability
```

**Explanations**:
- Use **bold** for important terms
- Use `code` for commands, file names, resource names
- Break complex topics into digestible parts
- Include diagrams/ASCII art where helpful

### Pull Request Process

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test all commands in the affected modules
5. Commit with clear messages: `docs: fix typo in networking module`
6. Push and create a pull request
7. Describe what you changed and why

### Commit Message Format

```
<type>: <short description>

<optional longer description>
```

Types:
- `docs`: Documentation changes
- `feat`: New content or features
- `fix`: Corrections to existing content
- `chore`: Maintenance tasks
- `refactor`: Restructuring without changing content

Examples:
- `docs: clarify ConfigMap mounting in module 03`
- `feat: add canary deployment example`
- `fix: correct service selector in networking module`

### Testing Checklist

Before submitting:
- [ ] All kubectl commands tested on fresh cluster
- [ ] YAML files are valid (`kubectl apply --dry-run=client`)
- [ ] Links work and point to correct sections
- [ ] No sensitive data (passwords, keys, etc.)
- [ ] Follows existing formatting and style

## Expert Module Contributions

Want to complete modules 02-06 in the expert track?
1. Review the existing outline in `expert/XX/README.md`
2. Follow the advanced networking module (01) as a template
3. Include production-grade examples
4. Add troubleshooting sections
5. Link to official documentation

## Questions?

- Open an issue with the `question` label
- Check existing issues/PRs for similar topics

## Code of Conduct

- Be respectful and inclusive
- Focus on what's best for learners
- Assume good intent
- Help newcomers

## Attribution

Contributors will be recognized in the README. By contributing, you agree to license your contributions under the MIT license.

---

Thank you for helping make Kubernetes more accessible! 🎉
