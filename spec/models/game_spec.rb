# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryGirl.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)

      # Ранее текущий вопрос стал предыдущим
      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'check .take_money!' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      game_w_questions.take_money!

      prize = game_w_questions.prize

      expect(prize).to be > 0

      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  context 'game status' do
    it ':in_progress' do
      expect(game_w_questions.status).to eq :in_progress
    end

    it ':fail' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.a)

      expect(game_w_questions.status).to eq :fail
    end

    it ':won' do
      15.times do
        q = game_w_questions.current_game_question
        game_w_questions.answer_current_question!(q.correct_answer_key)
      end

      expect(game_w_questions.status).to eq :won
    end

    it ':money' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      game_w_questions.take_money!

      expect(game_w_questions.status).to eq :money
    end

    it ':timeout' do
      game_w_questions.finished_at = Time.now
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true

      expect(game_w_questions.status).to eq :timeout
    end
  end

  describe '#current_game_question' do
    it 'should be third question' do
      game_w_questions.current_level = 2
      q = game_w_questions.game_questions.detect { |q| q.question.level == 2 }
      expect(game_w_questions.current_game_question).to eq q
    end
  end

  describe '#previous_level' do
    context 'When new game' do
      it 'should be -1' do
        expect(game_w_questions.previous_level).to eq -1
      end
    end

    context 'When 3 questions passed' do
      it 'should be 2' do
        3.times do
          q = game_w_questions.current_game_question
          game_w_questions.answer_current_question!(q.correct_answer_key)
        end

        expect(game_w_questions.previous_level).to eq 2
      end
    end
  end

  describe '#answer_current_question!' do
    context 'When correct answer' do
      it 'should be true' do
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_truthy
      end
    end

    context 'When last question' do
      it 'should be true' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max

        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_truthy
        expect(game_w_questions.current_level).to eq Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.prize).to eq 1000000
      end
    end

    context 'When wrong answer' do
      it 'should be false' do
        q = game_w_questions.current_game_question
        wrong_answer = q.correct_answer_key == 'a' ? 'b' : 'a'
        expect(game_w_questions.answer_current_question!(wrong_answer)).to be_falsey
      end
    end

    context 'When timeout' do
      it 'should be false' do
        game_w_questions.created_at = 1.hour.ago
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be_falsey
      end
    end
  end
end
