require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do

  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  context 'Anon' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end

  context 'Usual user' do
    before(:each) do
      sign_in user
    end

    it 'creates game' do
      generate_questions(60)

      post :create

      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.user).to eq user

      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_falsey
      expect(game.user).to eq user

      expect(response.status).to eq 200
      expect(response).to render_template('show')
    end

    context "When try to #show alien game" do
      it 'redirect to root' do
        alien_game = FactoryGirl.create(:game)

        get :show, id: alien_game.id

        expect(response.status).to_not eq 200
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be
      end
    end

    it 'answer correct' do
      put :answer,
          id: game_w_questions.id,
          letter: game_w_questions.current_game_question.correct_answer_key

      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy
    end

    context 'When #take_money before finished' do
      it 'finish game with prize' do
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money,
            id: game_w_questions.id

        game = assigns(:game)

        expect(game.finished?).to be_truthy
        expect(game.prize).to eq 200

        expect(response).to redirect_to(user_path(user))
        expect(flash[:warning]).to be

        user.reload
        expect(user.balance).to eq 200
      end
    end

    context 'When try to create second game' do
      it 'should redirect to the first game' do
        expect(game_w_questions.finished?).to be_falsey

        expect { post :create }.to change(Game, :count).by(0)

        game = assigns(:game)

        expect(game).to be_nil

        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end
  end
end
