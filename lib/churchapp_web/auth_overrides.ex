defmodule ChurchappWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :root_class, "flex flex-col items-center justify-center py-6 w-full"
    set :image_class, "h-12 w-auto mb-3"
    set :text_class, "text-xl font-bold text-gray-200"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :root_class,
        "min-h-screen w-full flex flex-col items-center justify-center px-4 py-12 bg-dark-900"

    set :form_class,
        "w-full max-w-md mx-auto space-y-6 bg-dark-800 p-8 rounded-lg border border-dark-600 shadow-xl"

    set :label_class, "block text-sm font-medium text-gray-200 mb-2"

    set :input_class,
        "appearance-none relative block w-full px-4 py-3 border border-dark-600 placeholder-gray-500 text-gray-100 bg-dark-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all"

    set :submit_class,
        "w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-semibold text-white bg-primary-500 hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all"

    set :slot_class, "text-center space-y-4"
    set :link_class, "text-sm text-primary-500 hover:text-primary-400 transition-colors"
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :root_class, "space-y-4"
    set :label_class, "block text-sm font-medium text-gray-200 mb-2"

    set :input_class,
        "appearance-none relative block w-full px-4 py-3 border border-dark-600 placeholder-gray-500 text-gray-100 bg-dark-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all"
  end

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set :root_class, "space-y-4"
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :root_class,
        "min-h-screen w-full flex flex-col items-center justify-center px-4 py-12 bg-dark-900"

    set :form_class,
        "w-full max-w-md space-y-6 bg-dark-800 p-8 rounded-lg border border-dark-600 shadow-xl"

    set :label_class, "block text-sm font-medium text-gray-200 mb-2"

    set :input_class,
        "appearance-none relative block w-full px-4 py-3 border border-dark-600 placeholder-gray-500 text-gray-100 bg-dark-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all"

    set :submit_class,
        "w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-semibold text-white bg-primary-500 hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all"
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :root_class,
        "min-h-screen w-full flex flex-col items-center justify-center px-4 py-12 bg-dark-900"

    set :form_class,
        "w-full max-w-md space-y-6 bg-dark-800 p-8 rounded-lg border border-dark-600 shadow-xl"

    set :label_class, "block text-sm font-medium text-gray-200 mb-2"

    set :input_class,
        "appearance-none relative block w-full px-4 py-3 border border-dark-600 placeholder-gray-500 text-gray-100 bg-dark-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all"

    set :submit_class,
        "w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-semibold text-white bg-primary-500 hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all"
  end
end
