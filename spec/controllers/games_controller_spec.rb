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

    it 'kick from #create' do
      post :create

      game = assigns(:game)
      expect(game).to be_nil

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #answer' do
      put :answer,
          id: game_w_questions.id,
          letter: game_w_questions.current_game_question.correct_answer_key

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money,
          id: game_w_questions.id

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

    it 'answer wrong' do
      game_w_questions.update_attribute(:current_level, 5)

      put :answer,
          id: game_w_questions.id,
          letter: 'a'

      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(game.status).to eq :fail
      expect(game.prize).to eq 1000

      expect(response).to redirect_to(user_path(user))
      expect(flash[:alert]).to be

      user.reload
      expect(user.balance).to eq 1000
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

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses fifty fifty help' do 
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.fifty_fifty_used).to be_truthy
      expect(game.current_game_question.help_hash[:fifty_fifty]).to be 
      expect(game.current_game_question.help_hash[:fifty_fifty]).to include 'd'
      expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
      expect(response).to redirect_to(game_path(game))
    end
  end
end
