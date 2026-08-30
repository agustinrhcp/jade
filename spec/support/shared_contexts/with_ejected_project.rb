RSpec.shared_context 'with an ejected project' do |sources, extra = {}|
  # Ejecting compiles the whole project, so it happens once for the group
  # rather than once per example.
  before(:context) { @ejected = Jade::EjectedProject.from_examples(*sources, **extra) }
  after(:context) { @ejected.cleanup }

  def ejected = @ejected
end
