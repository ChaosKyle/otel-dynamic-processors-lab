# Contributing to OpenTelemetry Dynamic Processors Lab

Thank you for your interest in contributing to this OpenTelemetry lab! This project aims to showcase advanced OpenTelemetry processor patterns and best practices.

## 🤝 How to Contribute

### Types of Contributions

- **🐛 Bug fixes** - Fix issues with configurations or scripts
- **📚 Documentation** - Improve explanations, add examples
- **🎯 New processors** - Add examples of new processor types
- **🔧 Enhancements** - Improve existing configurations
- **💡 Use cases** - Add real-world scenarios and examples

### Getting Started

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-processor`
3. **Make your changes**
4. **Test thoroughly** with `./scripts/deploy.sh deploy`
5. **Submit a pull request**

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/otel-docker-lab.git
cd otel-docker-lab

# Test the setup
./scripts/deploy.sh deploy
./scripts/deploy.sh status

# Run validation tests
./scripts/test-pipeline.sh
```

### Code Standards

- **Configuration files**: Use consistent YAML formatting
- **Documentation**: Update README.md for new features
- **Environment variables**: Use `.env` for configuration
- **Comments**: Explain complex processor logic

### Testing

Before submitting a PR, ensure:

- [ ] All services start successfully
- [ ] Processors are working as expected
- [ ] Documentation is updated
- [ ] Examples are tested
- [ ] Test pipeline passes: `./scripts/test-pipeline.sh`
- [ ] Configuration validation succeeds
- [ ] No sensitive data in commits

### Pull Request Process

1. Update documentation for any new processors
2. Add your example to the appropriate section
3. Test with different environments (dev, staging, prod)
4. Ensure the pipeline passes all health checks

## 🏷️ Processor Categories

When adding new processors, categorize them:

- **Resource Detection** - Infrastructure discovery
- **Attribute Transformation** - Data manipulation
- **Filtering** - Data reduction and routing
- **Metrics Transformation** - Metric processing
- **Custom Business Logic** - Domain-specific processing

## 📖 Documentation Guidelines

- Use clear, concise language
- Include practical examples
- Explain the "why" behind configurations
- Add troubleshooting tips for common issues

## 🚀 Feature Requests

Have an idea for a new processor example? Open an issue with:

- Use case description
- Expected behavior
- Sample configuration (if available)
- Business value

## 🐛 Bug Reports

When reporting bugs, include:

- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Relevant logs

## 📝 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## 💬 Community

- 💬 **Questions?** Open an issue with the `question` label
- 🗣️ **Discussions?** Use GitHub Discussions for general topics
- 🐛 **Bug reports?** Use the issue template with full details
- 💡 **Feature requests?** Use the feature request issue template
- ⭐ **Found this helpful?** Star the repository and share it!
- 📣 **Show your work?** Tag us when you use this lab in your projects

### Quick Help

- Use `./scripts/test-pipeline.sh --help` for testing options
- Check `docs/` folder for additional guides
- Review `helm/KUBERNETES.md` for Kubernetes deployment
- See existing issues for common questions

Thank you for making OpenTelemetry better for everyone! 🙏